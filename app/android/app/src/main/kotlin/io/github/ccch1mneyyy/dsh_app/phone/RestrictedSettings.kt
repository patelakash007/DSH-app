package io.github.ccch1mneyyy.dsh_app.phone

import android.app.AppOpsManager
import android.content.Context
import android.os.Build
import android.os.Process

object RestrictedSettings {
    const val GUARDED = "guarded"
    const val ACKNOWLEDGED = "acknowledged"
    const val CLEAR = "clear"

    private const val OP = "android:access_restricted_settings"

    // PackageInstaller.PACKAGE_SOURCE_* (API 33).
    private const val SOURCE_OTHER = 1
    private const val SOURCE_STORE = 2
    private const val SOURCE_LOCAL_FILE = 3
    private const val SOURCE_DOWNLOADED_FILE = 4

    /** The wire value for [mode] of the op on [sdk], given the app's [packageSource]. */
    fun state(sdk: Int, mode: Int?, packageSource: Int?): String? {
        if (sdk < 33) return CLEAR
        return when (mode) {
            AppOpsManager.MODE_ALLOWED -> CLEAR
            AppOpsManager.MODE_ERRORED -> GUARDED
            AppOpsManager.MODE_IGNORED -> ACKNOWLEDGED
            AppOpsManager.MODE_DEFAULT -> when (packageSource) {
                SOURCE_LOCAL_FILE, SOURCE_DOWNLOADED_FILE -> GUARDED
                SOURCE_STORE, SOURCE_OTHER -> CLEAR
                else -> null
            }
            else -> null
        }
    }

    /** This app's state now: [GUARDED], [ACKNOWLEDGED], [CLEAR], or null when it can't be told. */
    fun read(context: Context): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return CLEAR
        val mode = try {
            val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            ops.unsafeCheckOpRawNoThrow(OP, Process.myUid(), context.packageName)
        } catch (_: Exception) {
            // Unknown op string on this ROM, or the read was refused.
            return null
        }
        val source = try {
            context.packageManager.getInstallSourceInfo(context.packageName).packageSource
        } catch (_: Exception) {
            null
        }
        return state(Build.VERSION.SDK_INT, mode, source)
    }
}
