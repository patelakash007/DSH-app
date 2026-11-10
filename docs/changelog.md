# Changelog

All notable changes to the **DSH Native Android Release** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Removed
- Deleted the legacy PRoot / Ubuntu rootfs / Node.js engine stack: `runtime/` (rootfs builder, npm and pnpm locks, DSH patches, Node bridge and media plugin, PRoot/glibc shims, guard tests), the guest auth bridge, and the Kotlin direct-glibc launcher, rootfs extractor, XZ reader, guest overlays and their tests. The native Go engine is now the only engine in the repository.
- Removed the XZ dependency, PRoot JNI packaging and `runtime/out` source directories from the Android build.

### Changed
- Regenerated `app/android/app/src/main/assets/runtime/manifest.json` from the pinned engine lock, so the packaged `libdsh.so` is revision- and hash-verified at launch instead of silently skipping verification.

## [1.0.0] - 2026-11-09

### Added
- **Fresh Native v1.0.0 Release**: Rebranded and refactored as patelakash007's Native Android rewrite.
- **Direct Native Engine**: Integrated high-performance native on-device execution powered by DSH-Go, replacing legacy PRoot/Ubuntu environments.
- **Dual-View UI**: Seamlessly switch between the native Flutter client and embedded Web interface without losing conversation state.
- **Phone Control Automation**: Accessibility-based on-device screen inspection, tap simulation, and task automation with multi-level confirmation policies.
- **Live Mascot Companions**: Interactive desktop and in-app animations for Deepy and Whale girl with dynamic status reactions.
- **Native Plugin Architecture**: Extensible UI widgets, cards, and tool forms powered by `sdk/plugin-kit`.
- **End-to-End Encrypted Sharing**: Client-side encrypted chat replays, exportable snapshot cards, and secure web viewer links.
- **Adaptive Screen Layouts**: Responsive navigation and content scaling for mobile portrait, landscape, foldable screens, and tablets.
- **Remote Host Integration**: Connect to remote DSH servers via SSH or DSH Remote protocol.

### Changed
- Refactored all user documentation, development guides, and README files completely into clean, professional English.
- Eliminated all obsolete PRoot containers, chroot scripts, and Ubuntu userland dependencies.
- Updated `app/pubspec.yaml` to release version `1.0.0+1`.
- Cleaned git history to a pristine `v1.0.0` release tag on `main`.

### License & Attribution
- Preserved AGPL-3.0 licensing with attribution to upstream UI and recognition of patelakash007's Native Android rewrite.
