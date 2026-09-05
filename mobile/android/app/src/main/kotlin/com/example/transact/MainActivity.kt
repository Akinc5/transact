package com.example.transact

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.interfaces.ECPublicKey

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.transact/security"
    private val KEY_ALIAS = "TransactWalletKey"
    private val ANDROID_KEYSTORE = "AndroidKeyStore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isKeyGenerated" -> {
                    result.success(isKeyGenerated())
                }
                "generateKeyPair" -> {
                    generateKeyPair()
                    result.success(null)
                }
                "getPublicKeyHex" -> {
                    val pubKey = getPublicKeyHex()
                    if (pubKey.isNotEmpty()) {
                        result.success(pubKey)
                    } else {
                        result.error("KEYSTORE_ERROR", "Failed to retrieve public key", null)
                    }
                }
                "signPayload" -> {
                    val payload = call.argument<String>("payload")
                    if (payload != null) {
                        val signature = signPayload(payload)
                        if (signature.isNotEmpty()) {
                            result.success(signature)
                        } else {
                            result.error("SIGN_ERROR", "Failed to sign payload", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Payload was null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isKeyGenerated(): Boolean {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        return keyStore.containsAlias(KEY_ALIAS)
    }

    private fun generateKeyPair() {
        try {
            if (isKeyGenerated()) return
            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                ANDROID_KEYSTORE
            )
            val parameterSpec = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            ).run {
                setDigests(KeyProperties.DIGEST_SHA256)
                build()
            }
            keyPairGenerator.initialize(parameterSpec)
            keyPairGenerator.generateKeyPair()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getPublicKeyHex(): String {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val entry = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.PrivateKeyEntry
                ?: return ""
            val publicKey = entry.certificate.publicKey as? ECPublicKey ?: return ""

            val x = publicKey.w.affineX.toByteArray()
            val y = publicKey.w.affineY.toByteArray()

            val xClean = cleanCoordinate(x)
            val yClean = cleanCoordinate(y)

            val out = ByteArray(65)
            out[0] = 0x04
            System.arraycopy(xClean, 0, out, 1, 32)
            System.arraycopy(yClean, 0, out, 33, 32)

            bytesToHex(out)
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }

    private fun signPayload(payload: String): String {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val entry = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.PrivateKeyEntry
                ?: return ""
            val privateKey = entry.privateKey

            val signatureInstance = Signature.getInstance("SHA256withECDSA")
            signatureInstance.initSign(privateKey)
            signatureInstance.update(payload.toByteArray(Charsets.UTF_8))
            
            val signatureBytes = signatureInstance.sign()
            bytesToHex(signatureBytes)
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }

    private fun cleanCoordinate(co: ByteArray): ByteArray {
        val clean = ByteArray(32)
        if (co.size > 32) {
            System.arraycopy(co, co.size - 32, clean, 0, 32)
        } else if (co.size < 32) {
            System.arraycopy(co, 0, clean, 32 - co.size, co.size)
        } else {
            System.arraycopy(co, 0, clean, 0, 32)
        }
        return clean
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = CharArray(bytes.size * 2)
        val hexArray = "0123456789abcdef".toCharArray()
        for (i in bytes.indices) {
            val v = bytes[i].toInt() and 0xFF
            hexChars[i * 2] = hexArray[v >>> 4]
            hexChars[i * 2 + 1] = hexArray[v and 0x0F]
        }
        return String(hexChars)
    }
}
