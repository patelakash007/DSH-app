# Dynamic Launcher Icons Verification

Objective: Test app launcher icon switching (classic, whale-girl, monochrome, dark mode variant) via Android `activity-alias` components without data loss or unexpected process termination.

## Verification Checklist
1. Switch icon selection in Settings -> Appearance -> Launcher Icon.
2. Confirm the selected alias is enabled via `pm list components` while other aliases are disabled.
3. Verify launcher desktop updates the icon immediately or on next launch.
4. Ensure switching icons preserves app permissions, SharedPreferences, and database storage across Android 12, 13, and 14+.
5. Check monochrome adaptive icon theming support on Material You Android 13+ devices.
