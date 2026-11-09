package io.github.ccch1mneyyy.dsh_app.runtime

object VendorSettings {
    /**
     * One vendor activity, by component ([cls]) or by [action] inside [pkg]. [packageExtra] /
     * [labelExtra] name the extras that carry this app's package and label, when the page wants them.
     */
    data class Page(
        val pkg: String,
        val cls: String? = null,
        val action: String? = null,
        val packageExtra: String? = null,
        val labelExtra: String? = null,
    )

    /** A maker's switch, as the Dart side names it on the wire. */
    enum class Switch(val wire: String) {

        BACKGROUND("background"),

        AUTOSTART("autostart"),

        POPUP("popup");

        companion object {
            fun parse(wire: String?): Switch? = values().firstOrNull { it.wire == wire }
        }
    }

    const val VIVO = "vivo"
    const val XIAOMI = "xiaomi"
    const val HUAWEI = "huawei"
    const val HONOR = "honor"
    const val OPPO = "oppo"
    const val SAMSUNG = "samsung"

    /** The vendor key for `Build.MANUFACTURER` / `Build.BRAND`; null for stock Android and the rest. */
    fun vendorOf(manufacturer: String?, brand: String?): String? = match(manufacturer) ?: match(brand)

    private fun match(name: String?): String? {
        val n = name?.trim()?.lowercase() ?: return null
        fun any(vararg keys: String) = keys.any { n.startsWith(it) }
        return when {
            any("vivo", "iqoo") -> VIVO
            any("xiaomi", "redmi", "poco") -> XIAOMI
            // Older Honor phones say HUAWEI here and run Huawei's manager; checked first.
            any("huawei") -> HUAWEI
            any("honor", "hihonor") -> HONOR
            any("oppo", "oneplus", "realme") -> OPPO
            any("samsung") -> SAMSUNG
            else -> null
        }
    }

    private const val VIVO_PERMISSIONS = "com.vivo.permissionmanager"
    private const val IQOO_SECURE = "com.iqoo.secure"
    private const val MIUI_SECURITY = "com.miui.securitycenter"
    private const val HUAWEI_MANAGER = "com.huawei.systemmanager"
    private const val HONOR_MANAGER = "com.hihonor.systemmanager"

    fun pages(vendor: String?, switch: Switch = Switch.BACKGROUND): List<Page> = when (vendor) {
        VIVO -> when (switch) {
            Switch.BACKGROUND -> listOf(

                Page("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"),
                Page("com.iqoo.powersaving", "com.iqoo.powersaving.PowerSavingManagerActivity"),
            )
            Switch.AUTOSTART -> listOf(

                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                Page(IQOO_SECURE, "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
                Page(IQOO_SECURE, "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            )
            Switch.POPUP -> listOf(

                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity", packageExtra = "packagename"),
                Page(VIVO_PERMISSIONS, action = "permission.intent.action.softPermissionDetail", packageExtra = "packagename"),
                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.PurviewTabActivity"),
            )
        }
        XIAOMI -> when (switch) {

            Switch.BACKGROUND -> listOf(
                Page("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity", packageExtra = "package_name", labelExtra = "package_label"),
            )
            Switch.AUTOSTART -> listOf(Page(MIUI_SECURITY, "com.miui.permcenter.autostart.AutoStartManagementActivity"))

            Switch.POPUP -> listOf(
                Page(MIUI_SECURITY, "com.miui.permcenter.permissions.PermissionsEditorActivity", packageExtra = "extra_pkgname"),
                Page(MIUI_SECURITY, "com.miui.permcenter.permissions.AppPermissionsEditorActivity", packageExtra = "extra_pkgname"),
            )
        }
        HUAWEI -> if (switch == Switch.BACKGROUND) {
            listOf(
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            )
        } else {
            emptyList()
        }
        HONOR -> if (switch == Switch.BACKGROUND) {
            listOf(
                Page(HONOR_MANAGER, "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            )
        } else {
            emptyList()
        }
        else -> emptyList()
    }
}
