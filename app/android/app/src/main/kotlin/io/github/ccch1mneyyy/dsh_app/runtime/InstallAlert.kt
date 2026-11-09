package io.github.ccch1mneyyy.dsh_app.runtime

enum class InstallAlert {
    READY,
    FAILED;

    companion object {
        fun choose(ok: Boolean, inForeground: Boolean, notificationsEnabled: Boolean): InstallAlert? = when {
            inForeground || !notificationsEnabled -> null
            ok -> READY
            else -> FAILED
        }
    }
}
