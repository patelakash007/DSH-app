package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import java.io.File
import java.nio.file.Files

/**
 * True when [home] is the guest view's `root/.dsh` and either a real directory or
 * exactly the app-owned `dsh_home` beside that view. Any other symlink (a test's
 * or an attacker's redirect outside the runtime) is refused.
 */
internal fun isValidGuestHome(root: File, home: File): Boolean {
    if (!home.exists()) return false
    if (!Files.isSymbolicLink(home.toPath())) return home.isDirectory
    val parent = root.parentFile ?: return false
    return try {
        home.canonicalFile == File(parent, "dsh_home").canonicalFile
    } catch (_: Exception) {
        false
    }
}

/**
 * App-owned paths for the standalone Go backend. None is a guest Linux path,
 * and none depends on Termux or shared executable storage.
 */
data class NativeRuntimePaths private constructor(
    val home: File,
    val agentsHome: File,
    val workspaceRoot: File,
    val tempRoot: File,
    val logs: File,
    val phoneStorageRoot: File,
    /** Read-only migration input. Native startup must not create or require it. */
    val legacyRootfs: File,
    val versionFile: File,
) {
    fun prepare(): NativeRuntimePaths {
        listOf(home, agentsHome, workspaceRoot, tempRoot, logs, phoneStorageRoot).forEach { directory ->
            check(directory.mkdirs() || directory.isDirectory) { "could not create native runtime path ${directory.name}" }
        }
        return this
    }

    /**
     * A guest-root view for the app's home-relative recovery readers: `root/.dsh`,
     * `root/.agents` and `root/workspace` link to the native directories. The
     * engine itself never sees this view; it keeps the same paths the agent knows.
     */
    fun guestRoot(): File {
        val view = File(home.parentFile, "native-guest")
        val root = File(view, "root").apply { mkdirs() }
        linkInto(File(root, ".dsh"), home)
        linkInto(File(root, ".agents"), agentsHome)
        linkInto(File(root, "workspace"), workspaceRoot)
        return view
    }

    private fun linkInto(link: File, target: File) {
        try {
            if (Files.isSymbolicLink(link.toPath())) {
                if (Files.readSymbolicLink(link.toPath()).toString() == target.path) return
                Files.delete(link.toPath())
            } else if (link.exists()) {
                return
            }
            Files.createSymbolicLink(link.toPath(), target.toPath())
        } catch (_: Exception) {
            // No symlink support: readers see an absent path, never a wrong file.
        }
    }

    companion object {
        fun of(context: Context): NativeRuntimePaths {
            val files = context.filesDir
            val native = File(files, "native")
            return NativeRuntimePaths(
                // Keep the already-released home location; it contains the native SQLite stores.
                home = File(files, "dsh_home"),
                agentsHome = File(files, "agents_home"),
                // The pinned engine's contract test launches with `--home` alone and
                // reads `$home/workspace`; keep the workspace inside that home.
                workspaceRoot = File(files, "dsh_home/workspace"),
                tempRoot = File(context.cacheDir, "dsh-native"),
                logs = File(native, "logs"),
                phoneStorageRoot = File(native, "phone-storage"),
                legacyRootfs = File(files, "runtime/rootfs"),
                versionFile = File(native, "runtime.version"),
            )
        }
    }
}
