package com.shinrinyoku.glimpse

import android.content.Context
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.BlockstoreClient
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Durable, reinstall-surviving storage for the stable install id, backed by
 * Google Play Services Block Store.
 *
 * Block Store data is restored on reinstall via the device's existing Google
 * account (and, with cloud backup, onto a new device) — without any in-app
 * login. This keeps the worker's server-side AI quota, which is keyed on this
 * id, from being reset by a simple uninstall/reinstall.
 *
 * Bridges the `com.shinrinyoku.glimpse/stable_id` MethodChannel (see
 * `DurableIdStore` on the Dart side). All operations are fail-soft: a missing
 * value or any Block Store error reports back as "not found" / failure rather
 * than throwing, so the Dart side falls back to its local storage.
 */
class StableIdBridge(context: Context, messenger: BinaryMessenger) {
    private val client: BlockstoreClient = Blockstore.getClient(context)
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> read(result)
                "write" -> {
                    val id = call.argument<String>("id")
                    if (id.isNullOrEmpty()) {
                        result.error("bad_args", "missing id", null)
                    } else {
                        write(id, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun read(result: MethodChannel.Result) {
        val request = RetrieveBytesRequest.Builder()
            .setKeys(listOf(KEY))
            .build()
        client.retrieveBytes(request)
            .addOnSuccessListener { response ->
                val entry = response.blockstoreDataMap[KEY]
                val value = entry?.bytes?.toString(Charsets.UTF_8)
                result.success(if (value.isNullOrEmpty()) null else value)
            }
            .addOnFailureListener {
                // Fail-soft: treat as "not stored" so Dart mints/keeps locally.
                result.success(null)
            }
    }

    private fun write(id: String, result: MethodChannel.Result) {
        val data = StoreBytesData.Builder()
            .setBytes(id.toByteArray(Charsets.UTF_8))
            .setKey(KEY)
            // Survive onto a new device too when the user has cloud backup
            // (device backup + screen lock) enabled; otherwise stays local.
            .setShouldBackupToCloud(true)
            .build()
        client.storeBytes(data)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    companion object {
        private const val CHANNEL = "com.shinrinyoku.glimpse/stable_id"
        private const val KEY = "glimpse_stable_install_id"
    }
}
