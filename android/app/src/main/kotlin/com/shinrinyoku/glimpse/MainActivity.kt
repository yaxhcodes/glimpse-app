package com.shinrinyoku.glimpse

import android.content.Intent
import android.view.Display
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Flutter host activity for Glimpse.
 *
 * In addition to the default Flutter behavior, this activity catches
 * `ACTION_VIEW` intents that point at a `.json` Glimpse backup file (e.g.
 * when the user taps the file in a file manager and picks "Open with
 * Glimpse"). It copies the bytes from the supplied content/file URI into
 * the app's cache directory — Flutter can then read that path with plain
 * `dart:io` regardless of whether the original URI was content://, file://,
 * or anything else SAF-related.
 *
 * The cached path is exposed to Dart through a single MethodChannel:
 *
 *   - `getInitialBackupFile()`  → returns the path queued by a cold-start
 *                                 ACTION_VIEW intent, or null. Calling
 *                                 this consumes the value (subsequent
 *                                 calls return null until the next intent).
 *   - `onBackupFile(path)`      → invoked from native → Dart whenever a
 *                                 new ACTION_VIEW intent arrives while
 *                                 the app is already running.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.shinrinyoku.glimpse/backup_intent"
    private var methodChannel: MethodChannel? = null
    private var pendingBackupPath: String? = null
    private var storageBridge: BackupStorageBridge? = null
    private var stableIdBridge: StableIdBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) preferHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Persistent-folder bridge for backups (Mihon-style location).
        storageBridge = BackupStorageBridge(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )

        // Reinstall-surviving store for the stable install id (Block Store).
        stableIdBridge = StableIdBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialBackupFile" -> {
                        // First, check anything we already cached (cold-start
                        // intent caught before the engine was ready).
                        var path = pendingBackupPath
                        pendingBackupPath = null

                        // Otherwise, look at the launching intent in case
                        // configureFlutterEngine ran before our onCreate
                        // override could process it.
                        if (path == null) {
                            path = consumeBackupFromIntent(intent)
                        }
                        result.success(path)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // If the activity was created by an ACTION_VIEW intent and the
        // engine is now ready, push the file path immediately so the Dart
        // side can react without an explicit poll. This is mainly defensive
        // — `getInitialBackupFile()` covers the same case.
        pendingBackupPath?.let { path ->
            methodChannel?.invokeMethod("onBackupFile", path)
            pendingBackupPath = null
        }
    }

    private fun preferHighestRefreshRate() {
        val attrs = window.attributes

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = currentDisplay() ?: return
            val bestMode = display.supportedModes
                .maxWithOrNull(
                    compareBy<Display.Mode> { it.refreshRate }
                        .thenBy { it.physicalWidth * it.physicalHeight },
                )

            if (
                bestMode != null &&
                (attrs.preferredDisplayModeId != bestMode.modeId ||
                    attrs.preferredRefreshRate != bestMode.refreshRate)
            ) {
                attrs.preferredDisplayModeId = bestMode.modeId
                attrs.preferredRefreshRate = bestMode.refreshRate
                window.attributes = attrs
            }
        } else {
            @Suppress("DEPRECATION")
            val refreshRate = windowManager.defaultDisplay.refreshRate
            if (refreshRate > 0f && attrs.preferredRefreshRate != refreshRate) {
                attrs.preferredRefreshRate = refreshRate
                window.attributes = attrs
            }
        }
    }

    private fun currentDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Replace the activity's current intent so the cold-start path
        // (`getInitialBackupFile`) can also pick this up if the engine was
        // freshly started.
        setIntent(intent)

        val path = consumeBackupFromIntent(intent) ?: return
        val ch = methodChannel
        if (ch != null) {
            ch.invokeMethod("onBackupFile", path)
        } else {
            // Engine hasn't connected yet — queue for getInitialBackupFile().
            pendingBackupPath = path
        }
    }

    /**
     * If [intent] is an ACTION_VIEW pointing at a backup-shaped file,
     * copies its bytes into the cache directory and returns the cached
     * path. Otherwise returns null.
     *
     * We deliberately accept any file the user explicitly chose to open
     * with us — the Dart side validates the JSON and shows a friendly
     * error if it's not a real Glimpse backup.
     */
    private fun consumeBackupFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return null

        val uri: Uri = when (action) {
            Intent.ACTION_VIEW -> intent.data ?: return null
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val parcel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
                parcel ?: return null
            }
            else -> return null
        }

        val cachedPath = copyUriToCache(uri)

        // Strip the data so neither Flutter's deep-link forwarder nor any
        // other listener tries to interpret the URI again on subsequent
        // resumes (the activity reuses the launching intent until a new
        // one replaces it).
        if (cachedPath != null) {
            intent.data = null
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_STREAM)
        }

        return cachedPath
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val displayName = queryDisplayName(uri) ?: "incoming-backup.json"

            // Only act on files that look like backups, otherwise we'd
            // intercept every JSON the user ever opens.
            val lower = displayName.lowercase()
            if (!lower.endsWith(".json")) {
                // Allow it through anyway — Dart validates and reports a
                // friendly error if the file isn't a Glimpse backup.
            }

            val outFile = File(
                cacheDir,
                "incoming-backup-${System.currentTimeMillis()}-$displayName",
            )
            contentResolver.openInputStream(uri)?.use { input ->
                outFile.outputStream().use { output -> input.copyTo(output) }
            } ?: return null

            outFile.absolutePath
        } catch (t: Throwable) {
            android.util.Log.w("Glimpse", "copyUriToCache failed: $t")
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") {
            return uri.lastPathSegment
        }
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) cursor.getString(idx) else null
                } else null
            }
        } catch (t: Throwable) {
            null
        }
    }
}
