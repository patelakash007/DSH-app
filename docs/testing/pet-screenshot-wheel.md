# Floating Pet Radial Menu & Screenshot Verification

Objective: Long-press on desktop pet overlay, drag finger along radial wheel to select an action, and release to execute. "Screenshot & Ask DSH" captures the screen and returns to the composer in a new chat with the image staged, without auto-sending.

## Automated Regressions

Run from repository root:
```bash
(cd app && flutter analyze --no-pub)
(cd app && flutter test --no-pub test/system_entry test/web/web_mode_test.dart)
python3 app/tool/guide_sync.py --check
python3 app/tool/l10n_merge.py --check
```

Native unit tests use Android/JDK toolchain to run `:app:testX64DebugUnitTest`.

## On-Device Verification Steps

1. Long-press pet on left/right docks; drag to each radial slice. Check highlight and scale transitions. Release executes the selected action once.
2. Releasing without drag, dragging back to center, dragging out of bounds, system `ACTION_CANCEL`, screen rotation, or display timeout must cancel cleanly without triggering old selections.
3. Verify top/bottom docking, small screens, landscape orientation, and large accessibility font scaling.
4. On Android 11+ with accessibility enabled, trigger "Screenshot & Ask DSH": screenshot excludes pet, radial menu, and control overlays. App opens with image staged in the input area and composer focused.
5. Verify draft persistence: existing drafts in current or new chats are preserved. Staged screenshot remains editable; no model requests or uploads occur before explicit send.
6. Check fallback behavior when accessibility is missing, Android version is <= 10, or window is secure: clear error prompt, clean recovery, no leaked screenshot files in gallery.
