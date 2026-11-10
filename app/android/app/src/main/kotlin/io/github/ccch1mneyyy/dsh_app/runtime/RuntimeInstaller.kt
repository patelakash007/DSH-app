package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import java.io.File
import java.nio.file.Files

/**
 * Prepares and resets the standalone native runtime.
 *
 * There is nothing to extract: the Go engine ships as `libdsh.so` inside the
 * APK, and install only verifies its provenance and records the engine
 * version. [reset] clears the native home / agents home while preserving the
 * small user-owned set the UI asks to keep.
 *
 * Layout under filesDir:
 *   dsh_home/          the engine's --home (SQLite stores, settings, skills)
 *   agents_home/       the engine's AGENTS_HOME
 *   dsh_home/workspace the engine's workspace (inside --home)
 *   native/runtime.version  the installed engine version marker
 */
class RuntimeInstaller(
    private val context: Context,
    private val manifest: RuntimeManifest,
    private val onLog: (String) -> Unit,
) {
    private val paths = NativeRuntimePaths.of(context)

    /** Native home the engine runs with; also the root for user skills and drafts. */
    val home: File = paths.home

    /** The UI-facing version; the marker also carries the pinned engine revision. */
    fun installedVersion(): String? = marker()?.substringBefore(' ')

    /**
     * A bundled engine is current only when both the runtime version and the
     * pinned source revision match the marker written at install. An APK that
     * ships a rebuilt engine with the same version string therefore re-verifies
     * instead of reusing a stale marker forever.
     */
    fun isCurrent(): Boolean {
        if (!nativeBinary().isFile) return false
        val parts = marker()?.split(' ', limit = 2) ?: return false
        if (parts[0] != manifest.runtimeVersion) return false
        // Markers written before the revision was recorded stay valid; launch
        // still verifies the binary hash before executing it.
        val markerRevision = parts.getOrNull(1)
        return markerRevision == null || markerRevision == (manifest.engine?.revision ?: "")
    }

    private fun marker(): String? = try {
        paths.versionFile.takeIf { it.isFile }?.readText()?.trim()?.ifEmpty { null }
    } catch (_: Exception) {
        null
    }

    /**
     * Verifies the bundled engine against the manifest and marks the runtime
     * installed. [dropKept] is retained for the plugin-channel contract; a
     * native reset never leaves anything staged, so it has no effect.
     */
    fun install(@Suppress("UNUSED_PARAMETER") dropKept: Boolean = false, onProgress: (Long, Long) -> Unit) {
        val binary = nativeBinary()
        check(binary.isFile) { "native engine is missing from this APK" }
        val engine = manifest.engine ?: throw IllegalStateException("runtime manifest has no engine provenance")
        engine.verify(binary)
        paths.prepare()
        paths.versionFile.parentFile?.mkdirs()
        paths.versionFile.writeText("${manifest.runtimeVersion} ${engine.revision}")
        onLog("[dsh-app] native engine ready (${manifest.runtimeVersion}, ${manifest.abi})")
        onProgress(100, 100)
    }

    /** Deletes the native stores, keeping the paths the UI asked to preserve. */
    fun reset(keep: List<String>) {
        val preserved = mutableListOf<Pair<File, File>>()
        val staging = File(context.cacheDir, "native-reset-keep").apply { deleteRecursivelySafely() }
        try {
            for (rel in ResetKeep.ALL) {
                if (rel !in keep) continue
                val source = nativePathOf(rel) ?: continue
                if (!source.present()) continue
                val saved = File(staging, rel)
                saved.parentFile?.mkdirs()
                if (!source.renameTo(saved)) {
                    // Do not delete the home after a kept file failed to move: restore
                    // what already moved and leave the runtime intact for a retry.
                    preserved.forEach { (kept, target) ->
                        target.parentFile?.mkdirs()
                        kept.renameTo(target)
                    }
                    throw IllegalStateException("could not preserve ${source.name}")
                }
                preserved += saved to source
            }
            // The marker lives outside the home. Clear it first: a failure here must
            // not leave the app trusting a home that reset is about to delete.
            check(!paths.versionFile.exists() || paths.versionFile.delete()) { "could not clear the runtime marker" }
            paths.home.deleteRecursivelySafely()
            paths.agentsHome.deleteRecursivelySafely()
            // Workspace files used to live outside the home in early native builds.
            File(context.filesDir, "workspaces").deleteRecursivelySafely()
            paths.prepare()
            for ((saved, target) in preserved) {
                target.parentFile?.mkdirs()
                check(saved.renameTo(target)) { "could not restore ${target.name}" }
            }
        } finally {
            staging.deleteRecursivelySafely()
        }
    }

    private fun nativeBinary(): File = File(context.applicationInfo.nativeLibraryDir, "libdsh.so")

    /** Maps the legacy keep identifiers (kept stable for the Dart channel) to native paths. */
    private fun nativePathOf(rel: String): File? = when (rel) {
        "root/.dsh/dsh-go" -> File(paths.home, "dsh-go")
        "root/.dsh/skills" -> File(paths.home, "skills")
        "root/.agents/skills" -> File(paths.agentsHome, "skills")
        // The native engine's settings and its key/value store (account, credentials
        // and provider state). The Cordis profile files below do not exist natively.
        "root/.dsh/native-settings.json" -> File(paths.home, "native-settings.json")
        "root/.dsh/kv.db" -> File(paths.home, "kv.db")
        else -> null
    }
}

/** The runtime cannot be changed while it is running or mid-recovery. */
internal class RuntimeUpgradeBlocked(reason: String) : IllegalStateException("runtime_upgrade_blocked:$reason")

/**
 * Paths a reset can keep. The wire names and path identifiers are part of the
 * Flutter channel contract; [RuntimeInstaller.reset] maps them onto native
 * storage.
 */
enum class ResetKeep(val wire: String, val paths: List<String>) {
    UI_AND_SKILLS("uiAndSkills", listOf("root/.dsh/dsh-go", "root/.dsh/skills", "root/.agents/skills")),
    // The native engine has no Cordis profiles; its settings layer is native-settings.json
    // and its key/value store holds account and provider state. Keep both when asked to
    // keep settings, instead of pretending to keep files that do not exist.
    PLUGINS_AND_SETTINGS("pluginsAndSettings", listOf("root/.dsh/native-settings.json", "root/.dsh/kv.db"));

    companion object {
        val ALL: List<String> = entries.flatMap { it.paths }

        fun fromWire(names: Collection<String>): Set<ResetKeep> = entries.filterTo(LinkedHashSet()) { it.wire in names }
    }
}

/** Recursive delete that removes symlinks without following them and copes with read-only dirs. */
internal fun File.deleteRecursivelySafely() {
    if (isSymlink()) {
        delete()
        return
    }
    if (isDirectory) {
        if (!canWrite()) runCatching { android.system.Os.chmod(path, 0x1C0) } // 0700
        if (!canWrite()) setWritable(true) // no android.system off the device (JVM tests)
        listFiles()?.forEach { it.deleteRecursivelySafely() }
    }
    delete()
}

private fun File.isSymlink(): Boolean = try {
    android.system.OsConstants.S_ISLNK(android.system.Os.lstat(path).st_mode)
} catch (_: Exception) {
    // No android.system off the device (JVM tests).
    runCatching { Files.isSymbolicLink(toPath()) }.getOrDefault(false)
}

/** Exists, counting a symlink whose target is gone. */
private fun File.present(): Boolean = exists() || isSymlink()
