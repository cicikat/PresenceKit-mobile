package com.presencekit.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CredentialMigrationTest {
    @Test fun `migrates legacy credential then removes plaintext`() {
        val secure = FakeSecure()
        val legacy = FakeLegacy(mapOf("adminToken" to "secret-value"))

        assertEquals("secret-value", CredentialMigration.readOrMigrate("adminToken", secure, legacy))
        assertEquals("secret-value", secure.values["adminToken"])
        assertNull(legacy.values["adminToken"])
    }

    @Test fun `failed secure write preserves legacy credential`() {
        val secure = FakeSecure(failWrites = true)
        val legacy = FakeLegacy(mapOf("adminToken" to "secret-value"))

        assertEquals("secret-value", CredentialMigration.readOrMigrate("adminToken", secure, legacy))
        assertEquals("secret-value", legacy.values["adminToken"])
    }

    @Test fun `secure credential wins and migration is idempotent`() {
        val secure = FakeSecure(mapOf("adminToken" to "secure-value"))
        val legacy = FakeLegacy(mapOf("adminToken" to "legacy-value"))

        assertEquals("secure-value", CredentialMigration.readOrMigrate("adminToken", secure, legacy))
        assertEquals("secure-value", CredentialMigration.readOrMigrate("adminToken", secure, legacy))
        assertEquals(0, secure.writeCalls)
        assertNull(legacy.values["adminToken"])
    }

    @Test fun `replace and delete update secure storage and clear legacy`() {
        val secure = FakeSecure()
        val legacy = FakeLegacy(mapOf("adminToken" to "old"))

        assertTrue(CredentialMigration.replace("adminToken", "new", secure, legacy))
        assertEquals("new", secure.values["adminToken"])
        assertNull(legacy.values["adminToken"])
        assertTrue(CredentialMigration.replace("adminToken", "", secure, legacy))
        assertNull(secure.values["adminToken"])
    }

    @Test fun `failed replacement does not clear legacy`() {
        val secure = FakeSecure(failWrites = true)
        val legacy = FakeLegacy(mapOf("adminToken" to "old"))

        assertFalse(CredentialMigration.replace("adminToken", "new", secure, legacy))
        assertEquals("old", legacy.values["adminToken"])
    }

    private class FakeSecure(
        initial: Map<String, String> = emptyMap(),
        private val failWrites: Boolean = false,
    ) : SecureCredentialStorage {
        val values = initial.toMutableMap()
        var writeCalls = 0
        override fun read(key: String) = values[key]
        override fun write(key: String, value: String): Boolean {
            writeCalls++
            if (failWrites) return false
            values[key] = value
            return true
        }
        override fun delete(key: String): Boolean = values.remove(key) != null || !failWrites
    }

    private class FakeLegacy(initial: Map<String, String>) : LegacyCredentialStorage {
        val values = initial.toMutableMap()
        override fun read(key: String) = values[key]
        override fun delete(key: String): Boolean { values.remove(key); return true }
    }
}
