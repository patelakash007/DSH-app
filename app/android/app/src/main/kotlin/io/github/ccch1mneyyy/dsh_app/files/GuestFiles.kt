package io.github.ccch1mneyyy.dsh_app.files

import android.content.Context
import io.github.ccch1mneyyy.dsh_app.runtime.NativeRuntimePaths
import io.github.ccch1mneyyy.dsh_app.runtime.PhoneStorage
import java.io.File

/**
 * Where a path reported by the engine lives on Android.
 *
 * The native engine keeps the same homes the agent already knows as guest
 * paths, but directly under the app's files directory:
 *
 *   /root/.dsh      -> filesDir/dsh_home
 *   /root/.agents   -> filesDir/agents_home
 *   /root/workspace -> filesDir/dsh_home/workspace
 *   /sdcard         -> the app's shared-storage root
 *
 * A path that is already an app-private host path is accepted too. Resolution
 * is confined to these roots and only returns readable regular files.
 */
object GuestFiles {
    private data class Root(val guest: String, val host: File)

    /** Host file for an absolute engine [path]; null when it is not a readable regular file. */
    fun resolve(context: Context, path: String): File? = resolve(context, NativeRuntimePaths.of(context), path, File(PhoneStorage.hostRoot()))

    internal fun resolve(context: Context, paths: NativeRuntimePaths, path: String, phoneRoot: File): File? {
        if (!path.startsWith("/")) return null
        val roots = listOf(
            Root("/root/.dsh", paths.home),
            Root("/root/.agents", paths.agentsHome),
            Root("/root/workspace", paths.workspaceRoot),
            Root(PhoneStorage.GUEST_PATH, phoneRoot),
            Root("/storage/emulated/0", phoneRoot),
        )
        val match = roots.filter { path == it.guest || path.startsWith(it.guest + "/") }
            .maxByOrNull { it.guest.length }
        if (match != null) {
            val relative = path.removePrefix(match.guest).removePrefix("/")
            return confined(match.host, relative)
        }
        // Native engine messages may already name the app-private file directly.
        return directHost(context, path)
    }

    private fun directHost(context: Context, path: String): File? = try {
        val base = context.filesDir.canonicalFile
        val target = File(path).canonicalFile
        target.takeIf { it.path.startsWith(base.path + File.separator) && it.isFile && it.canRead() }
    } catch (_: Exception) {
        null
    }

    /** [relative] under [root], refusing anything that canonicalizes outside it. */
    private fun confined(root: File, relative: String): File? = try {
        val base = root.canonicalFile
        val target = File(base, relative.removePrefix("/")).canonicalFile
        val inside = target == base || target.path.startsWith(base.path + File.separator)
        target.takeIf { inside && it.isFile && it.canRead() }
    } catch (_: Exception) {
        null
    }
}
