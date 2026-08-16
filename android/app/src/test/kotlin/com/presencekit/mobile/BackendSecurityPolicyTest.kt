package com.presencekit.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendSecurityPolicyTest {
    @Test fun `normalizes and permits confirmation of tailscale magic dns origins`() {
        val origin = BackendSecurityPolicy.normalizeOrigin(
            "http://vm-0-2-ubuntu.tail786b19.ts.net",
        )

        assertEquals("http://vm-0-2-ubuntu.tail786b19.ts.net", origin)
        assertTrue(BackendSecurityPolicy.isConfirmablePrivateCleartextOrigin(origin!!))
    }

    @Test fun `does not treat lookalike public domains as tailscale magic dns`() {
        assertFalse(
            BackendSecurityPolicy.isConfirmablePrivateCleartextOrigin(
                "http://vm-0-2-ubuntu.tail786b19.ts.net.example.com",
            ),
        )
        assertFalse(
            BackendSecurityPolicy.isConfirmablePrivateCleartextOrigin("http://ts.net"),
        )
    }
}
