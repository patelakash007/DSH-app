package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import java.io.File

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

    companion object {
        fun of(context: Context): NativeRuntimePaths {
            val files = context.filesDir
            val native = File(files, "native")
            return NativeRuntimePaths(
                // Keep the already-released home location; it contains the native SQLite stores.
                home = File(files, "dsh_home"),
                agentsHome = File(files, "agents_home"),
                workspaceRoot = File(files, "workspaces/default"),
                tempRoot = File(context.cacheDir, "dsh-native"),
                logs = File(native, "logs"),
                phoneStorageRoot = File(native, "phone-storage"),
                legacyRootfs = File(files, "runtime/rootfs"),
                versionFile = File(native, "runtime.version"),
            )
        }
    }
}
