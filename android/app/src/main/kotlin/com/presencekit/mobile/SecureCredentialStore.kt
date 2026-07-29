package com.presencekit.mobile

import android.content.Context
import android.os.Build
import android.security.KeyPairGeneratorSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.math.BigInteger
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.util.Calendar
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import javax.security.auth.x500.X500Principal

interface SecureCredentialStorage {
    fun read(key: String): String?
    fun write(key: String, value: String): Boolean
    fun delete(key: String): Boolean
}

interface LegacyCredentialStorage {
    fun read(key: String): String?
    fun delete(key: String): Boolean
}

/** Never deletes a legacy secret until its secure write has committed. */
object CredentialMigration {
    fun readOrMigrate(key: String, secure: SecureCredentialStorage, legacy: LegacyCredentialStorage): String? {
        secure.read(key)?.trim()?.takeIf { it.isNotEmpty() }?.let { value ->
            legacy.delete(key)
            return value
        }
        val legacyValue = legacy.read(key)?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return if (secure.write(key, legacyValue)) {
            legacy.delete(key)
            legacyValue
        } else legacyValue
    }

    fun replace(key: String, value: String, secure: SecureCredentialStorage, legacy: LegacyCredentialStorage): Boolean {
        val changed = if (value.isBlank()) secure.delete(key) else secure.write(key, value.trim())
        if (changed) legacy.delete(key)
        return changed
    }
}

/** Android Keystore holds the non-exportable key; only ciphertext is in private preferences. */
class AndroidKeystoreCredentialStore(private val context: Context) : SecureCredentialStorage {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun read(key: String): String? = runCatching {
        val encoded = prefs.getString(key, null) ?: return null
        when {
            encoded.startsWith(AES_PREFIX) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> decryptAes(encoded)
            encoded.startsWith(RSA_PREFIX) -> decryptRsa(encoded)
            else -> null
        }
    }.getOrNull()

    override fun write(key: String, value: String): Boolean = runCatching {
        val encoded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) encryptAes(value) else encryptRsa(value)
        prefs.edit().putString(key, encoded).commit()
    }.getOrDefault(false)

    override fun delete(key: String): Boolean = runCatching { prefs.edit().remove(key).commit() }.getOrDefault(false)

    private fun encryptAes(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, aesKey())
        return AES_PREFIX + Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" +
            Base64.encodeToString(cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8)), Base64.NO_WRAP)
    }

    private fun decryptAes(encoded: String): String? {
        val parts = encoded.removePrefix(AES_PREFIX).split(":", limit = 2)
        if (parts.size != 2) return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, aesKey(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
        return String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8)
    }

    private fun aesKey(): javax.crypto.SecretKey {
        val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? javax.crypto.SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .build())
        return generator.generateKey()
    }

    private fun encryptRsa(value: String): String {
        val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
        cipher.init(Cipher.ENCRYPT_MODE, rsaKeyStore().getCertificate(KEY_ALIAS).publicKey)
        return RSA_PREFIX + Base64.encodeToString(cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8)), Base64.NO_WRAP)
    }

    private fun decryptRsa(encoded: String): String? {
        val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
        cipher.init(Cipher.DECRYPT_MODE, rsaKeyStore().getKey(KEY_ALIAS, null))
        return String(cipher.doFinal(Base64.decode(encoded.removePrefix(RSA_PREFIX), Base64.NO_WRAP)), StandardCharsets.UTF_8)
    }

    private fun rsaKeyStore(): KeyStore {
        val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (!store.containsAlias(KEY_ALIAS)) {
            val start = Calendar.getInstance()
            val end = Calendar.getInstance().apply { add(Calendar.YEAR, 30) }
            KeyPairGenerator.getInstance("RSA", ANDROID_KEYSTORE).apply {
                initialize(KeyPairGeneratorSpec.Builder(context).setAlias(KEY_ALIAS)
                    .setSubject(X500Principal("CN=PresenceKit Credential")).setSerialNumber(BigInteger.ONE)
                    .setStartDate(start.time).setEndDate(end.time).build())
                generateKeyPair()
            }
        }
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    companion object {
        private const val PREFS_NAME = "presencekit_secure_credentials"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "com.presencekit.mobile.credentials.v1"
        private const val AES_PREFIX = "v2:"
        private const val RSA_PREFIX = "v1:"
    }
}
