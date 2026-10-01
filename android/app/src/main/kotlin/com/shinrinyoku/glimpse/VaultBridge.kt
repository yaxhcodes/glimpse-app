package com.shinrinyoku.glimpse

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

/**
 * The Vault's lock, held by Android rather than by Glimpse.
 *
 * Bridges `com.shinrinyoku.glimpse/vault` (see `VaultCrypto` on the Dart
 * side). An RSA key pair lives in the Android Keystore; its private half can
 * only be used for a few seconds after the person proves who they are with
 * the phone's own fingerprint, face or screen lock. Nothing Glimpse stores
 * can open the vault without it, and removing the screen lock destroys it.
 *
 * Two sealed forms:
 *  - **Envelope** (v1): a fresh AES key per item, wrapped with the public
 *    key. Needs no unlock, so the share sheet can file into a locked vault.
 *  - **Session** (v2): AES-GCM under the vault's data key. The data key is
 *    itself wrapped with the public key; unlocking unwraps it once, so an
 *    open vault reads every item in software instead of one Keystore
 *    operation each. Envelopes are re-sealed as session items on unlock.
 *
 * The unwrapped data key lives only in this process's memory, until `lock`.
 */
class VaultBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "seal" -> background(result) {
                    val plain = call.argument<ByteArray>("plain")
                        ?: throw IllegalArgumentException("missing plain")
                    seal(plain)
                }
                "unlock" -> unlock(
                    title = call.argument<String>("title") ?: "",
                    subtitle = call.argument<String>("subtitle"),
                    wrappedDataKey = call.argument<ByteArray>("wrappedDataKey"),
                    result = result,
                )
                "open" -> background(result) {
                    val sealed = call.argument<List<ByteArray>>("sealed") ?: emptyList()
                    open(sealed)
                }
                // Identity only, no key: for acts as final as a reset, which
                // must work even when the key itself is gone.
                "confirm" -> {
                    if (!isDeviceSecure()) {
                        result.success("no_screen_lock")
                    } else {
                        val host = activity as? FragmentActivity
                        if (host == null) {
                            result.success("failed")
                        } else {
                            prompt(
                                host,
                                call.argument<String>("title") ?: "",
                                call.argument<String>("subtitle"),
                            ) { outcome -> result.success(outcome) }
                        }
                    }
                }
                "lock" -> {
                    VaultSession.clear()
                    result.success(null)
                }
                "reset" -> background(result) {
                    VaultSession.clear()
                    val store = keyStore()
                    if (store.containsAlias(KEY_ALIAS)) store.deleteEntry(KEY_ALIAS)
                    null
                }
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") == true
                    if (secure) {
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Status ────────────────────────────────────────────────────────────

    private fun status(): Map<String, Any> = mapOf(
        "screenLock" to isDeviceSecure(),
        "key" to keyState(),
        "unlocked" to (VaultSession.dataKey != null),
    )

    private fun isDeviceSecure(): Boolean {
        val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguard.isDeviceSecure
    }

    /** "missing", "invalidated" (the screen lock was removed), or "ready". */
    private fun keyState(): String {
        return try {
            val key = privateKey() ?: return "missing"
            Cipher.getInstance(RSA).init(Cipher.DECRYPT_MODE, key, OAEP)
            "ready"
        } catch (_: UserNotAuthenticatedException) {
            "ready"
        } catch (_: KeyPermanentlyInvalidatedException) {
            "invalidated"
        } catch (t: Throwable) {
            android.util.Log.w("Glimpse", "vault key probe failed: $t")
            "invalidated"
        }
    }

    // ── Sealing ───────────────────────────────────────────────────────────

    private fun seal(plain: ByteArray): ByteArray {
        val session = VaultSession.dataKey
        if (session != null) return sealWith(VERSION_SESSION, session, plain, null)
        if (!isDeviceSecure()) throw VaultException("no_screen_lock")
        if (keyState() == "invalidated") throw VaultException("invalidated")
        val itemKey = ByteArray(32).also { random.nextBytes(it) }
        val wrapped = wrap(itemKey)
        return sealWith(VERSION_ENVELOPE, itemKey, plain, wrapped)
    }

    private fun sealWith(
        version: Byte,
        key: ByteArray,
        plain: ByteArray,
        wrapped: ByteArray?,
    ): ByteArray {
        val iv = ByteArray(IV_BYTES).also { random.nextBytes(it) }
        val cipher = Cipher.getInstance(AES)
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD(byteArrayOf(version))
        val body = cipher.doFinal(plain)
        val header = if (wrapped == null) 1 else 3 + wrapped.size
        return ByteBuffer.allocate(header + iv.size + body.size).apply {
            put(version)
            if (wrapped != null) {
                putShort(wrapped.size.toShort())
                put(wrapped)
            }
            put(iv)
            put(body)
        }.array()
    }

    /** Each item opened, or null where it couldn't be (yet). */
    private fun open(sealed: List<ByteArray>): List<ByteArray?> {
        val session = VaultSession.dataKey ?: throw VaultException("locked")
        var privateKey: PrivateKey? = null
        return sealed.map { blob ->
            try {
                val buffer = ByteBuffer.wrap(blob)
                val version = buffer.get()
                val key = when (version) {
                    VERSION_SESSION -> session
                    VERSION_ENVELOPE -> {
                        val wrapped = ByteArray(buffer.short.toInt() and 0xFFFF)
                        buffer.get(wrapped)
                        val owner = privateKey ?: privateKey()?.also { privateKey = it }
                            ?: return@map null
                        unwrap(owner, wrapped)
                    }
                    else -> return@map null
                }
                val iv = ByteArray(IV_BYTES).also { buffer.get(it) }
                val body = ByteArray(buffer.remaining()).also { buffer.get(it) }
                val cipher = Cipher.getInstance(AES)
                cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
                cipher.updateAAD(byteArrayOf(version))
                cipher.doFinal(body)
            } catch (t: Throwable) {
                android.util.Log.w("Glimpse", "vault item could not be opened: ${t.javaClass.simpleName}")
                null
            }
        }
    }

    // ── Unlocking ─────────────────────────────────────────────────────────

    private fun unlock(
        title: String,
        subtitle: String?,
        wrappedDataKey: ByteArray?,
        result: MethodChannel.Result,
    ) {
        if (!isDeviceSecure()) return result.success(mapOf("status" to "no_screen_lock"))
        try {
            if (privateKey() == null) {
                // A data key with no Keystore key: restored onto another phone,
                // or wiped by Android. What it sealed can't be opened here.
                if (wrappedDataKey != null) return result.success(mapOf("status" to "invalidated"))
                generateKeyPair()
            }
        } catch (t: Throwable) {
            android.util.Log.w("Glimpse", "vault key could not be created: $t")
            return result.success(mapOf("status" to "failed"))
        }
        if (keyState() == "invalidated") return result.success(mapOf("status" to "invalidated"))

        val host = activity as? FragmentActivity
            ?: return result.success(mapOf("status" to "failed"))
        prompt(host, title, subtitle) { outcome ->
            if (outcome != "ok") return@prompt result.success(mapOf("status" to outcome))
            worker.execute {
                val unwrapped = runCatching { startSession(wrappedDataKey) }
                main.post {
                    val error = unwrapped.exceptionOrNull()
                    when {
                        error == null -> result.success(
                            mapOf("status" to "ok", "wrappedDataKey" to unwrapped.getOrNull()),
                        )
                        // A weak face unlock passed the prompt but doesn't
                        // authorise Keystore keys on older Android: confirm
                        // with the screen lock itself, then try once more.
                        error is UserNotAuthenticatedException -> confirmCredential(host, title, subtitle) { confirmed ->
                            if (!confirmed) return@confirmCredential result.success(mapOf("status" to "cancelled"))
                            worker.execute {
                                val retry = runCatching { startSession(wrappedDataKey) }
                                main.post {
                                    result.success(
                                        if (retry.isSuccess) {
                                            mapOf("status" to "ok", "wrappedDataKey" to retry.getOrNull())
                                        } else {
                                            mapOf("status" to statusFor(retry.exceptionOrNull()))
                                        },
                                    )
                                }
                            }
                        }
                        else -> result.success(mapOf("status" to statusFor(error)))
                    }
                }
            }
        }
    }

    private fun statusFor(error: Throwable?): String = when (error) {
        is KeyPermanentlyInvalidatedException -> "invalidated"
        is UserNotAuthenticatedException -> "cancelled"
        else -> "failed"
    }

    /**
     * Unwraps the data key into memory. With none yet, makes one and returns
     * its wrapped form for Dart to keep.
     */
    private fun startSession(wrappedDataKey: ByteArray?): ByteArray? {
        val owner = privateKey() ?: throw VaultException("missing")
        // Fails here, not later, if the unlock didn't authorise the key.
        val probe = Cipher.getInstance(RSA)
        probe.init(Cipher.DECRYPT_MODE, owner, OAEP)
        if (wrappedDataKey != null) {
            VaultSession.dataKey = probe.doFinal(wrappedDataKey)
            return null
        }
        val fresh = ByteArray(32).also { random.nextBytes(it) }
        VaultSession.dataKey = fresh
        return wrap(fresh)
    }

    private fun prompt(
        host: FragmentActivity,
        title: String,
        subtitle: String?,
        done: (String) -> Unit,
    ) {
        var finished = false
        fun finish(outcome: String) {
            if (finished) return
            finished = true
            done(outcome)
        }
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                finish("ok")
            }

            override fun onAuthenticationError(code: Int, message: CharSequence) {
                finish(
                    when (code) {
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "lockout"
                        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "no_screen_lock"
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_CANCELED -> "cancelled"
                        else -> "failed"
                    },
                )
            }
            // A finger that doesn't match keeps the prompt open; nothing to do.
        }
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .apply { if (!subtitle.isNullOrBlank()) setSubtitle(subtitle) }
            .setAllowedAuthenticators(authenticators())
            .setConfirmationRequired(false)
            .build()
        try {
            BiometricPrompt(host, ContextCompat.getMainExecutor(host), callback).authenticate(info)
        } catch (t: Throwable) {
            android.util.Log.w("Glimpse", "vault prompt failed: $t")
            finish("failed")
        }
    }

    /** Strong biometrics or the screen lock; older Android can't pair those. */
    private fun authenticators(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL
        } else {
            Authenticators.BIOMETRIC_WEAK or Authenticators.DEVICE_CREDENTIAL
        }

    @Suppress("DEPRECATION")
    private fun confirmCredential(
        host: FragmentActivity,
        title: String,
        subtitle: String?,
        done: (Boolean) -> Unit,
    ) {
        val keyguard = host.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = keyguard.createConfirmDeviceCredentialIntent(title, subtitle)
            ?: return done(false)
        val key = "glimpse_vault_confirm_${System.nanoTime()}"
        var launcher: androidx.activity.result.ActivityResultLauncher<android.content.Intent>? = null
        launcher = host.activityResultRegistry.register(
            key,
            ActivityResultContracts.StartActivityForResult(),
        ) { outcome ->
            launcher?.unregister()
            done(outcome.resultCode == Activity.RESULT_OK)
        }
        launcher.launch(intent)
    }

    // ── Keys ──────────────────────────────────────────────────────────────

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun privateKey(): PrivateKey? = keyStore().getKey(KEY_ALIAS, null) as? PrivateKey

    /** The public half, as a plain key: encrypting with it needs no unlock. */
    private fun publicKey(): PublicKey {
        val certificate = keyStore().getCertificate(KEY_ALIAS)
            ?: generateKeyPair().let { keyStore().getCertificate(KEY_ALIAS) }
            ?: throw VaultException("failed")
        val encoded = certificate.publicKey.encoded
        return KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(encoded))
    }

    private fun wrap(secret: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(RSA)
        cipher.init(Cipher.ENCRYPT_MODE, publicKey(), OAEP)
        return cipher.doFinal(secret)
    }

    private fun unwrap(owner: PrivateKey, wrapped: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(RSA)
        cipher.init(Cipher.DECRYPT_MODE, owner, OAEP)
        return cipher.doFinal(wrapped)
    }

    private fun generateKeyPair() {
        if (!isDeviceSecure()) throw VaultException("no_screen_lock")
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(2048)
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA1)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(true)
            // A new fingerprint shouldn't wipe the vault; removing the screen
            // lock still does (Android's rule, not ours).
            .setInvalidatedByBiometricEnrollment(false)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(
                        AUTH_WINDOW_SECONDS,
                        KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setUserAuthenticationValidityDurationSeconds(AUTH_WINDOW_SECONDS)
                }
            }
            .build()
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, KEYSTORE).apply {
            initialize(spec)
            generateKeyPair()
        }
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            val outcome = runCatching(work)
            main.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { error ->
                        val code = (error as? VaultException)?.code
                            ?: if (error is KeyPermanentlyInvalidatedException) "invalidated" else "failed"
                        result.error(code, error.message, null)
                    },
                )
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    private class VaultException(val code: String) : Exception(code)

    companion object {
        private const val CHANNEL = "com.shinrinyoku.glimpse/vault"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "glimpse_vault_rsa_v1"
        private const val RSA = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
        private const val AES = "AES/GCM/NoPadding"
        private const val IV_BYTES = 12
        private const val AUTH_WINDOW_SECONDS = 15
        private const val VERSION_ENVELOPE: Byte = 1
        private const val VERSION_SESSION: Byte = 2

        // Keystore OAEP takes SHA-1 for MGF1 on every Android version.
        private val OAEP = OAEPParameterSpec(
            "SHA-256",
            "MGF1",
            MGF1ParameterSpec.SHA1,
            PSource.PSpecified.DEFAULT,
        )
        private val random = SecureRandom()
    }
}

/** The open vault's data key: process memory only, until locked. */
private object VaultSession {
    @Volatile
    var dataKey: ByteArray? = null

    fun clear() {
        dataKey?.fill(0)
        dataKey = null
    }
}
