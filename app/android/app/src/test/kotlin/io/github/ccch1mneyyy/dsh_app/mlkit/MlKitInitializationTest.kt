package io.github.ccch1mneyyy.dsh_app.mlkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class MlKitInitializationTest {
    @Test
    fun `successful initialization runs once`() {
        val state = MlKitInitialization()
        var calls = 0
        state.ensureInitialized { calls++ }
        state.ensureInitialized { calls++ }
        assertEquals(1, calls)
    }

    @Test
    fun `failed initialization is not retried`() {
        val state = MlKitInitialization()
        assertThrows(IllegalArgumentException::class.java) {
            state.ensureInitialized { throw IllegalArgumentException("broken SDK") }
        }
        assertThrows(IllegalStateException::class.java) {
            state.ensureInitialized { error("must not run") }
        }
    }
}
