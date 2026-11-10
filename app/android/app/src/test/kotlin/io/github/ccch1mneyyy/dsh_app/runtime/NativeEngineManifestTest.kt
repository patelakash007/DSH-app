package io.github.ccch1mneyyy.dsh_app.runtime

import java.io.File
import java.security.MessageDigest
import kotlin.io.path.createTempDirectory
import org.junit.Assert.assertThrows
import org.junit.Test

class NativeEngineManifestTest {
    @Test
    fun `clean pinned engine with matching bytes verifies`() {
        val directory = createTempDirectory("native-engine-manifest").toFile()
        val binary = File(directory, "libdsh.so").apply { writeBytes("native-engine".toByteArray()) }
        manifest(binary).verify(binary)
        directory.deleteRecursively()
    }

    @Test
    fun `dirty or changed engine fails closed`() {
        val directory = createTempDirectory("native-engine-manifest").toFile()
        val binary = File(directory, "libdsh.so").apply { writeBytes("native-engine".toByteArray()) }
        assertThrows(IllegalStateException::class.java) { manifest(binary, dirty = true).verify(binary) }
        val expected = manifest(binary)
        binary.appendText("changed")
        assertThrows(IllegalStateException::class.java) { expected.verify(binary) }
        directory.deleteRecursively()
    }

    private fun manifest(binary: File, dirty: Boolean = false): NativeEngineManifest {
        val digest = MessageDigest.getInstance("SHA-256").digest(binary.readBytes()).joinToString("") { "%02x".format(it) }
        return NativeEngineManifest(
            repository = "https://github.com/patelakash007/DSH-go-rewrite",
            revision = "e3243e06855a61f0d1ccd623bf199157abf74566",
            sha256 = digest,
            bytes = binary.length(),
            protocolVersion = "native-v1",
            sourceDirty = dirty,
            capabilities = setOf("agent-tools-v1"),
        )
    }
}
