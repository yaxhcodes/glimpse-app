package com.shinrinyoku.glimpse

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the persistent-backup-folder feature.
 *
 * Surfaces a single MethodChannel (`com.shinrinyoku.glimpse/backup_storage`)
 * with three jobs:
 *
 *  - Let the user pick a folder via Storage Access Framework
 *    (`ACTION_OPEN_DOCUMENT_TREE`) and persist the granted URI permission
 *    so we can keep writing into it across app restarts.
 *  - Report the currently configured folder back to Dart, both as a raw
 *    URI (for plumbing) and as a human-friendly label (for the UI, e.g.
 *    `/storage/emulated/0/Documents/Glimpse`).
 *  - Write a backup file (provided as bytes by Dart) into that folder.
 *
 * Mihon-equivalent: this is the "Storage location" + "Create backup" pair
 * on their Data and storage screen — the user picks a folder once, and
 * subsequent backups go straight into it without re-prompting.
 */
class BackupStorageBridge(
    private val activity: ComponentActivity,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    companion object {
        private const val CHANNEL = "com.shinrinyoku.glimpse/backup_storage"
        private const val PREFS = "glimpse_backup_storage"
        private const val KEY_TREE_URI = "tree_uri"
        private const val TAG = "Glimpse"

        /** Single canonical name; older builds used dated `glimpse-backup-*.json`. */
        private fun isManagedBackupFileName(name: String?): Boolean {
            if (name == null) return false
            if (name == "glimpse-backup.json") return true
            return name.startsWith("glimpse-backup-") && name.endsWith(".json")
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingPickResult: MethodChannel.Result? = null

    /**
     * Registered against the activity's lifecycle. Must be created BEFORE
     * the activity's STARTED state — i.e. inside `onCreate`. We do that
     * by constructing this bridge in `MainActivity.configureFlutterEngine`,
     * which Flutter invokes from `onCreate`.
     */
    private val pickLauncher: ActivityResultLauncher<Uri?> =
        activity.registerForActivityResult(
            ActivityResultContracts.OpenDocumentTree(),
        ) { uri ->
            val resultHandle = pendingPickResult
            pendingPickResult = null
            if (uri == null) {
                resultHandle?.success(null) // user cancelled
                return@registerForActivityResult
            }
            try {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                activity.contentResolver.takePersistableUriPermission(uri, flags)
                activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_TREE_URI, uri.toString())
                    .apply()
                resultHandle?.success(uri.toString())
            } catch (t: Throwable) {
                android.util.Log.w(TAG, "takePersistableUriPermission failed: $t")
                resultHandle?.error(
                    "PERMISSION_FAILED",
                    t.message ?: "Could not persist folder permission",
                    null,
                )
            }
        }

    init {
        channel.setMethodCallHandler { call, result -> dispatch(call, result) }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickLocation" -> pickLocation(result)
            "currentLocationUri" -> result.success(currentTreeUri())
            "currentLocationLabel" -> result.success(currentLocationLabel())
            "clearLocation" -> {
                clearLocation()
                result.success(null)
            }
            "writeBackup" -> writeBackup(call, result)
            "listBackups" -> listBackups(result)
            else -> result.notImplemented()
        }
    }

    private fun pickLocation(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "A folder picker is already open", null)
            return
        }
        pendingPickResult = result
        try {
            // Pass null so the picker opens at the last-used location.
            pickLauncher.launch(null)
        } catch (t: Throwable) {
            pendingPickResult = null
            result.error("LAUNCH_FAILED", t.message, null)
        }
    }

    private fun currentTreeUri(): String? {
        val raw = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TREE_URI, null) ?: return null

        // If the user revoked the permission via system settings or
        // uninstalled the storage provider, the URI is still in our prefs
        // but useless. Drop it so the UI shows "no location set" again.
        val held = activity.contentResolver.persistedUriPermissions
            .any { it.uri.toString() == raw && it.isWritePermission }
        return if (held) raw else {
            clearLocation()
            null
        }
    }

    private fun currentLocationLabel(): String? {
        val raw = currentTreeUri() ?: return null
        return describeTreeUri(raw)
    }

    private fun clearLocation() {
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_TREE_URI)
            .apply()
    }

    /**
     * Writes [bytes] to `<folder>/<fileName>`, replacing any existing file
     * with that name (the SAF default would otherwise be `name (1).json`).
     * Returns the document URI we ended up writing to, or fails the
     * Flutter call.
     */
    private fun writeBackup(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName == null || bytes == null) {
            result.error(
                "ARGS",
                "fileName and bytes are required",
                null,
            )
            return
        }

        val treeUri = currentTreeUri()
        if (treeUri == null) {
            result.error(
                "NO_LOCATION",
                "No backup folder configured",
                null,
            )
            return
        }

        try {
            val tree = DocumentFile.fromTreeUri(activity, Uri.parse(treeUri))
            if (tree == null || !tree.canWrite()) {
                result.error(
                    "FOLDER_UNWRITABLE",
                    "The chosen folder is no longer writable",
                    null,
                )
                return
            }

            // Keep at most one Glimpse backup in the folder (canonical + legacy dated names).
            for (child in tree.listFiles()) {
                if (child.isFile && isManagedBackupFileName(child.name)) {
                    child.delete()
                }
            }

            val target = tree.createFile("application/json", fileName)
            if (target == null) {
                result.error(
                    "CREATE_FAILED",
                    "Could not create the file in the chosen folder",
                    null,
                )
                return
            }

            activity.contentResolver.openOutputStream(target.uri)?.use { os ->
                os.write(bytes)
                os.flush()
            } ?: run {
                result.error(
                    "WRITE_FAILED",
                    "Could not open output stream for the file",
                    null,
                )
                return
            }

            result.success(
                mapOf(
                    "uri" to target.uri.toString(),
                    "displayName" to (target.name ?: fileName),
                    "label" to currentLocationLabel(),
                ),
            )
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "writeBackup failed: $t")
            result.error("WRITE_EXCEPTION", t.message, null)
        }
    }

    /**
     * Lists `.json` files in the configured backup folder, newest first.
     * Returns a list of maps with `name` and `uri`.
     */
    private fun listBackups(result: MethodChannel.Result) {
        val treeUri = currentTreeUri()
        if (treeUri == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        try {
            val tree = DocumentFile.fromTreeUri(activity, Uri.parse(treeUri))
                ?: return result.success(emptyList<Map<String, String>>())

            val items = tree.listFiles()
                .filter { it.isFile && isManagedBackupFileName(it.name) }
                .sortedByDescending { it.lastModified() }
                .map {
                    mapOf(
                        "name" to (it.name ?: ""),
                        "uri" to it.uri.toString(),
                        "lastModified" to it.lastModified().toString(),
                    )
                }
            result.success(items)
        } catch (t: Throwable) {
            result.error("LIST_FAILED", t.message, null)
        }
    }

    /**
     * Best-effort "Documents/Glimpse"-style label for a tree URI. SAF tree
     * URIs encode a `tree/<authority>:<path>` document id; for the
     * external storage provider that's `primary:Documents/Glimpse`, which
     * we render as `/storage/emulated/0/Documents/Glimpse` to match the
     * format users see in Mihon and in their file manager.
     */
    private fun describeTreeUri(rawUri: String): String {
        return try {
            val uri = Uri.parse(rawUri)
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val parts = docId.split(":", limit = 2)
            if (parts.size == 2 && parts[0] == "primary") {
                if (parts[1].isEmpty()) {
                    "/storage/emulated/0"
                } else {
                    "/storage/emulated/0/${parts[1]}"
                }
            } else if (parts.size == 2) {
                // External SD / OTG / cloud provider.
                "${parts[0]}: ${parts[1]}"
            } else {
                docId
            }
        } catch (t: Throwable) {
            rawUri
        }
    }
}
