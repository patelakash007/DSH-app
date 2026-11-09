package io.github.ccch1mneyyy.dsh_app.phone.a11y

internal object ScreenVerdict {
    const val UNCHANGED = "界面没有明显变化。"
    const val SCROLL_END = "内容没有变化，可能已经到头了。"
    // l10n:keep agent screen result
    const val UNVERIFIABLE = "（动作已提交，但无法验证结果：缺少足够的可读内容，可能受敏感视图策略限制。）"
    const val KEYBOARD_HIDDEN = "键盘已收起。"
    const val KEYBOARD_SHOWN = "键盘已弹出。"

    fun note(comparable: Boolean, changed: Boolean, keyboard: String?, scrolled: Boolean): String = when {
        !comparable -> listOfNotNull(keyboard, UNVERIFIABLE).joinToString("")
        keyboard != null -> keyboard
        changed -> ""
        scrolled -> SCROLL_END
        else -> UNCHANGED
    }
}
