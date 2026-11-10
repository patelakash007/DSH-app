package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import android.os.Build
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * Describes the runtime bundled in this APK flavor. Native release manifests
 * carry exact Go source/binary provenance; old manifests describe the
 * temporary Linux fallback during the migration window.
 */
data class RuntimeManifest(
    val runtimeVersion: String,
    val abi: String,
    val rootfsAsset: String,
    val rootfsBytes: Long,
    val rootfsSha256: String?,
    val uncompressedBytes: Long,
    val dshVersion: String,
    val nodeVersion: String,
    /** Optional extra engine arguments from the manifest (empty for the native manifest). */
    val launchArgv: List<String>,
    val launchEnv: Map<String, String>,
    val raw: JSONObject,
    val engine: NativeEngineManifest? = null,
) {
    companion object {
        const val ASSET_DIR = "runtime"

        fun load(context: Context): RuntimeManifest {
            val text = try {
                context.assets.open("$ASSET_DIR/manifest.json").bufferedReader().use { it.readText() }
            } catch (_: Exception) {
                return RuntimeManifest(
                    runtimeVersion = "native-1.0.0",
                    abi = Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
                    rootfsAsset = "",
                    rootfsBytes = 0L,
                    rootfsSha256 = null,
                    uncompressedBytes = 0L,
                    dshVersion = "1.0.0-native",
                    nodeVersion = "go-native",
                    launchArgv = emptyList(),
                    launchEnv = emptyMap(),
                    raw = JSONObject(),
                    engine = null,
                )
            }
            val json = JSONObject(text)
            val launch = json.optJSONObject("launch") ?: JSONObject()
            val argvJson = launch.optJSONArray("argv")
            val argv = if (argvJson != null) List(argvJson.length()) { argvJson.getString(it) } else emptyList()
            val envJson = launch.optJSONObject("env") ?: JSONObject()
            val env = envJson.keys().asSequence().associateWith { envJson.getString(it) }
            return RuntimeManifest(
                runtimeVersion = json.getString("runtimeVersion"),
                abi = json.optString("abi"),
                rootfsAsset = json.optString("rootfs"),
                rootfsBytes = json.optLong("rootfsBytes", -1L),
                rootfsSha256 = json.optString("rootfsSha256").ifEmpty { null },
                uncompressedBytes = json.optLong("uncompressedBytes", -1L),
                dshVersion = json.optString("dshVersion"),
                nodeVersion = json.optString("nodeVersion"),
                launchArgv = argv,
                launchEnv = env,
                raw = json,
                engine = json.optJSONObject("engine")?.let { NativeEngineManifest.fromJson(it) },
            )
        }
    }
}

data class NativeEngineManifest(
    val repository: String,
    val revision: String,
    val sha256: String,
    val bytes: Long,
    val protocolVersion: String,
    val sourceDirty: Boolean,
    val capabilities: Set<String>,
) {
    fun verify(binary: File) {
        check(!sourceDirty) { "native engine provenance is marked dirty" }
        check(revision.matches(Regex("[0-9a-fA-F]{40}"))) { "native engine revision is not pinned" }
        check(binary.isFile) { "native engine binary is missing" }
        if (bytes >= 0) check(binary.length() == bytes) { "native engine size does not match its manifest" }
        if (sha256.isNotEmpty()) {
            val digest = MessageDigest.getInstance("SHA-256")
            FileInputStream(binary).use { input ->
                val buffer = ByteArray(128 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    digest.update(buffer, 0, read)
                }
            }
            val actual = digest.digest().joinToString("") { "%02x".format(it) }
            check(actual.equals(sha256, ignoreCase = true)) { "native engine checksum does not match its manifest" }
        }
    }

    companion object {
        fun fromJson(json: JSONObject): NativeEngineManifest {
            val capabilities = json.optJSONArray("capabilities")
            return NativeEngineManifest(
                repository = json.optString("repository"),
                revision = json.optString("revision"),
                sha256 = json.optString("sha256"),
                bytes = json.optLong("bytes", -1L),
                protocolVersion = json.optString("protocolVersion"),
                sourceDirty = json.optBoolean("sourceDirty", true),
                capabilities = if (capabilities == null) emptySet() else
                    (0 until capabilities.length()).mapTo(linkedSetOf()) { capabilities.getString(it) },
            )
        }
    }
}
