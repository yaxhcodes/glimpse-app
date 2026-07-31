package com.shinrinyoku.glimpse.backupstorage

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * Storage Access Framework bridge used by both the foreground app and
 * WorkManager's headless Flutter engine.
 */
class GlimpseBackupStoragePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    companion object {
        private const val CHANNEL = "com.shinrinyoku.glimpse/backup_storage"
        private const val PREFS = "glimpse_backup_storage"
        private const val KEY_TREE_URI = "tree_uri"
        private const val PICK_REQUEST_CODE = 47291

        private val ioExecutor = Executors.newSingleThreadExecutor()

        private fun isManagedBackupFileName(name: String?): Boolean {
            val value = name?.lowercase() ?: return false
            if (value == "glimpse-backup.json") return true
            if (Regex("""glimpse-backup \(\d+\)\.json""").matches(value)) {
                return true
            }
            return value.startsWith("glimpse-backup-") && value.endsWith(".json")
        }
    }

    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity(cancelPendingPicker = false)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity(cancelPendingPicker = true)
    }

    private fun detachActivity(cancelPendingPicker: Boolean) {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        if (cancelPendingPicker) {
            pendingPickResult?.error("NO_ACTIVITY", "The folder picker was closed", null)
            pendingPickResult = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickLocation" -> pickLocation(result)
            "currentLocationUri" -> result.success(currentTreeUri())
            "currentLocationLabel" -> result.success(currentLocationLabel())
            "clearLocation" -> {
                clearLocation(releasePermission = true)
                result.success(null)
            }
            "writeBackup" -> writeBackup(call, result)
            "listBackups" -> listBackups(result)
            else -> result.notImplemented()
        }
    }

    private fun pickLocation(result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "A visible activity is required to pick a folder", null)
            return
        }
        if (pendingPickResult != null) {
            result.error("BUSY", "A folder picker is already open", null)
            return
        }

        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        try {
            activity.startActivityForResult(intent, PICK_REQUEST_CODE)
        } catch (error: Throwable) {
            pendingPickResult = null
            result.error("LAUNCH_FAILED", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST_CODE) return false

        val result = pendingPickResult
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return true
        }

        val uri = data.data!!
        try {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            applicationContext.contentResolver.takePersistableUriPermission(uri, flags)

            val oldUri = storedTreeUri()
            applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TREE_URI, uri.toString())
                .apply()
            if (oldUri != null && oldUri != uri.toString()) {
                releasePermission(oldUri)
            }
            result?.success(uri.toString())
        } catch (error: Throwable) {
            result?.error(
                "PERMISSION_FAILED",
                error.message ?: "Could not persist folder permission",
                null,
            )
        }
        return true
    }

    private fun storedTreeUri(): String? =
        applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TREE_URI, null)

    private fun currentTreeUri(): String? {
        val raw = storedTreeUri() ?: return null
        val held = applicationContext.contentResolver.persistedUriPermissions.any {
            it.uri.toString() == raw && it.isReadPermission && it.isWritePermission
        }
        if (held) return raw
        clearLocation(releasePermission = false)
        return null
    }

    private fun currentLocationLabel(): String? =
        currentTreeUri()?.let(::describeTreeUri)

    private fun clearLocation(releasePermission: Boolean) {
        val raw = storedTreeUri()
        applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_TREE_URI)
            .apply()
        if (releasePermission && raw != null) releasePermission(raw)
    }

    private fun releasePermission(raw: String) {
        try {
            applicationContext.contentResolver.releasePersistableUriPermission(
                Uri.parse(raw),
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Already revoked by Android or the document provider.
        }
    }

    private fun writeBackup(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName == null || bytes == null) {
            result.error("ARGS", "fileName and bytes are required", null)
            return
        }

        ioExecutor.execute {
            try {
                val writeResult = writeBackupFile(fileName, bytes)
                activityBinding?.activity?.runOnUiThread { result.success(writeResult) }
                    ?: android.os.Handler(applicationContext.mainLooper).post {
                        result.success(writeResult)
                    }
            } catch (error: Throwable) {
                android.os.Handler(applicationContext.mainLooper).post {
                    result.error("WRITE_FAILED", error.message, null)
                }
            }
        }
    }

    private fun writeBackupFile(fileName: String, bytes: ByteArray): Map<String, String> {
        val treeUri = currentTreeUri()
            ?: throw IllegalStateException("No backup folder configured")
        val tree = DocumentFile.fromTreeUri(applicationContext, Uri.parse(treeUri))
            ?: throw IllegalStateException("Could not open the configured backup folder")
        if (!tree.canWrite()) throw IllegalStateException("The chosen folder is no longer writable")

        val managedFiles = tree.listFiles().filter {
            it.isFile && isManagedBackupFileName(it.name)
        }
        val target = managedFiles.firstOrNull { it.name.equals(fileName, ignoreCase = true) }
            ?: tree.createFile("application/json", fileName)
            ?: throw IllegalStateException("Could not create the backup file")

        val resolver = applicationContext.contentResolver
        var output = try {
            resolver.openOutputStream(target.uri, "rwt")
        } catch (_: Throwable) {
            null
        }
        if (output == null) {
            output = resolver.openOutputStream(target.uri, "w")
        }
        output ?: throw IllegalStateException("Could not open the backup file for writing")
        output.use {
            it.write(bytes)
            it.flush()
        }

        // Only remove legacy/suffixed snapshots after the canonical write has
        // completed. The single-thread executor also prevents manual and
        // automatic writes from deleting or interleaving with each other.
        managedFiles
            .filter { it.uri != target.uri }
            .forEach { it.delete() }

        return mapOf(
            "uri" to target.uri.toString(),
            "displayName" to (target.name ?: fileName),
            "label" to (currentLocationLabel() ?: ""),
        )
    }

    private fun listBackups(result: MethodChannel.Result) {
        ioExecutor.execute {
            try {
                val treeUri = currentTreeUri()
                val items = if (treeUri == null) {
                    emptyList()
                } else {
                    val tree = DocumentFile.fromTreeUri(applicationContext, Uri.parse(treeUri))
                    tree?.listFiles()
                        ?.filter { it.isFile && isManagedBackupFileName(it.name) }
                        ?.sortedByDescending { it.lastModified() }
                        ?.map {
                            mapOf(
                                "name" to (it.name ?: ""),
                                "uri" to it.uri.toString(),
                                "lastModified" to it.lastModified().toString(),
                            )
                        }
                        ?: emptyList()
                }
                android.os.Handler(applicationContext.mainLooper).post { result.success(items) }
            } catch (error: Throwable) {
                android.os.Handler(applicationContext.mainLooper).post {
                    result.error("LIST_FAILED", error.message, null)
                }
            }
        }
    }

    private fun describeTreeUri(rawUri: String): String {
        return try {
            val uri = Uri.parse(rawUri)
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val parts = docId.split(":", limit = 2)
            when {
                parts.size == 2 && parts[0] == "primary" && parts[1].isEmpty() ->
                    "/storage/emulated/0"
                parts.size == 2 && parts[0] == "primary" ->
                    "/storage/emulated/0/${parts[1]}"
                parts.size == 2 -> "${parts[0]}: ${parts[1]}"
                else -> docId
            }
        } catch (_: Throwable) {
            rawUri
        }
    }
}
