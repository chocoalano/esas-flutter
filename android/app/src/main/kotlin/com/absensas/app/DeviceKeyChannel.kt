package com.absensas.app

import android.annotation.TargetApi
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.ProviderException
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The attendance device key (ADR-D §5, §10): one EC P-256 signing key per
 * account on this install, generated inside AndroidKeyStore. The Dart side
 * passes the keystore alias, derived from the workspace and the user, so a
 * second account or another workspace on the same phone never uses or
 * replaces this account's key (PO 4.2.8). The private key never leaves the
 * keystore and is not part of any backup; only the public key (X.509 SPKI DER)
 * and signatures cross the channel.
 *
 * A channel of its own, `esas/device_key`, so the CORE-03 `esas/device`
 * identifier channel in [MainActivity] stays exactly as it is.
 *
 * Keystore work runs on one background thread (StrongBox generation can take a
 * second or more) and every reply is posted back to the main thread, which is
 * where Flutter requires a [MethodChannel.Result] to be completed.
 */
class DeviceKeyChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "esas/device_key"
        private const val PROVIDER = "AndroidKeyStore"

        /** What Dart may name a key: short, and nothing a keystore could misread. */
        private val ALIAS_PATTERN = Regex("^[A-Za-z0-9._-]{1,128}$")

        private val worker: ExecutorService by lazy { Executors.newSingleThreadExecutor() }
        private val main = Handler(Looper.getMainLooper())
    }

    private class KeyError(val code: String, message: String) : Exception(message)

    private fun aliasOf(call: MethodCall): String {
        val alias = call.argument<String>("alias")
            ?: throw KeyError("INVALID_ARGUMENT", "alias is required")
        if (!ALIAS_PATTERN.matches(alias)) throw KeyError("INVALID_ARGUMENT", "alias is malformed")
        return alias
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "capabilities" -> capabilities(
                        call.argument<String>("alias")?.takeIf { ALIAS_PATTERN.matches(it) },
                    )
                    "generate" -> generate(aliasOf(call), call.argument<Boolean>("replace") == true)
                    "publicKey" -> publicKey(aliasOf(call))
                    "sign" -> sign(
                        aliasOf(call),
                        call.argument<ByteArray>("bytes")
                            ?: throw KeyError("INVALID_ARGUMENT", "bytes is required"),
                    )
                    "delete" -> {
                        delete(aliasOf(call))
                        null
                    }
                    "exists" -> keyStore().containsAlias(aliasOf(call))
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (error: KeyError) {
                main.post { result.error(error.code, error.message, null) }
            } catch (error: Exception) {
                // The class name only: a keystore message can carry key material
                // descriptions that have no business in a log on the Dart side.
                main.post { result.error("KEY_UNAVAILABLE", error.javaClass.simpleName, null) }
            }
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }

    private fun privateKey(store: KeyStore, alias: String): PrivateKey? =
        store.getKey(alias, null) as? PrivateKey

    /** What this handset can do, before or after a key exists under [alias]. */
    private fun capabilities(alias: String?): Map<String, Any?> {
        val store = try {
            keyStore()
        } catch (error: Exception) {
            null
        }
        val existing = if (store != null && alias != null && store.containsAlias(alias)) {
            privateKey(store, alias)
        } else {
            null
        }
        val claim = existing?.let { describe(it, strongBoxGenerated = null) }

        return mapOf(
            "available" to (store != null),
            "hardwareBackedClaimed" to (claim?.get("hardwareBackedClaimed") ?: false),
            "strongBox" to (claim?.get("strongBox") ?: hasStrongBox()),
            "platform" to "android",
        )
    }

    /**
     * Create the key, or describe the existing one.
     *
     * An existing key is replaced only when [replace] is true. StrongBox is
     * tried first on API 28+, and the Trusted Execution Environment is used
     * when the handset has no StrongBox.
     */
    private fun generate(alias: String, replace: Boolean): Map<String, Any?> {
        val store = keyStore()

        if (store.containsAlias(alias)) {
            if (!replace) {
                val existing = privateKey(store, alias)
                    ?: throw KeyError("KEY_MISSING", "no private key")
                return describe(existing, strongBoxGenerated = null)
            }
            store.deleteEntry(alias)
        }

        var strongBox = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            strongBox = generateInStrongBox(alias)
        }
        if (!strongBox) {
            generateWith(spec(alias, strongBox = false))
        }

        val created = privateKey(keyStore(), alias)
            ?: throw KeyError("KEY_UNAVAILABLE", "key not stored")
        return describe(created, strongBoxGenerated = strongBox)
    }

    @TargetApi(Build.VERSION_CODES.P)
    private fun generateInStrongBox(alias: String): Boolean = try {
        generateWith(spec(alias, strongBox = true))
        true
    } catch (error: StrongBoxUnavailableException) {
        cleanUpPartialKey(alias)
        false
    } catch (error: ProviderException) {
        // Some handsets advertise StrongBox and then fail inside it. The TEE is
        // the documented fallback, so it is taken here too.
        cleanUpPartialKey(alias)
        false
    }

    private fun cleanUpPartialKey(alias: String) {
        try {
            val store = keyStore()
            if (store.containsAlias(alias)) store.deleteEntry(alias)
        } catch (ignored: Exception) {
            // Nothing to clean up, or nothing that can be.
        }
    }

    private fun spec(alias: String, strongBox: Boolean): KeyGenParameterSpec {
        val builder = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)

        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        return builder.build()
    }

    private fun generateWith(spec: KeyGenParameterSpec) {
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, PROVIDER)
        generator.initialize(spec)
        generator.generateKeyPair()
    }

    /**
     * The hardware claim, from [KeyInfo]. A claim and nothing more: the server
     * stores it as `hardware_backed_claimed` and decides nothing on it until key
     * attestation is verified (ADR-D §5, stage 5).
     */
    private fun describe(key: PrivateKey, strongBoxGenerated: Boolean?): Map<String, Any?> {
        val info = try {
            KeyFactory.getInstance(key.algorithm, PROVIDER).getKeySpec(key, KeyInfo::class.java)
        } catch (error: Exception) {
            null
        }

        var hardware = false
        var strongBox = strongBoxGenerated ?: false

        if (info != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val level = info.securityLevel
                hardware = level == KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT ||
                    level == KeyProperties.SECURITY_LEVEL_STRONGBOX ||
                    level == KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE
                strongBox = level == KeyProperties.SECURITY_LEVEL_STRONGBOX
            } else {
                @Suppress("DEPRECATION")
                hardware = info.isInsideSecureHardware
            }
        }

        return mapOf(
            "available" to true,
            "hardwareBackedClaimed" to hardware,
            "strongBox" to strongBox,
            "platform" to "android",
        )
    }

    private fun hasStrongBox(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)

    /** The public key as X.509 SubjectPublicKeyInfo DER, base64 (standard). */
    private fun publicKey(alias: String): String {
        val certificate = keyStore().getCertificate(alias)
            ?: throw KeyError("KEY_MISSING", "no key under the alias")
        return Base64.encodeToString(certificate.publicKey.encoded, Base64.NO_WRAP)
    }

    /** `SHA256withECDSA` over exactly [message]; DER signature, base64 (standard). */
    private fun sign(alias: String, message: ByteArray): String {
        val key = privateKey(keyStore(), alias)
            ?: throw KeyError("KEY_MISSING", "no key under the alias")
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(key)
        signature.update(message)
        return Base64.encodeToString(signature.sign(), Base64.NO_WRAP)
    }

    private fun delete(alias: String) {
        val store = keyStore()
        if (store.containsAlias(alias)) store.deleteEntry(alias)
    }
}
