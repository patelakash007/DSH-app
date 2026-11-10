# Contributing to DSH

Thank you for your interest in contributing to **DSH** (Native Android rewrite).

## Issue Reporting and Feature Suggestions

For bug reports, feature requests, or improvements, please open an issue on GitHub:
https://github.com/patelakash007/DSH-app/issues

When reporting a bug, please include:
- App version and build number (e.g., `v1.0.0`)
- Android OS version and device architecture (arm64-v8a / x86_64)
- Host connection type (Native On-Device, SSH, or DSH Remote)
- Clear, minimal steps to reproduce the issue
- Relevant error logs with sensitive tokens and personal data redacted

For security vulnerabilities and credential safety concerns, please refer to [SECURITY.md](SECURITY.md).

## Development Setup

To build the project locally, ensure you have the required prerequisites:
- **Flutter**: Follow the version specified in `app/pubspec.yaml`
- **Dart**: SDK `^3.13.5`
- **Android SDK / NDK**: JDK 17, Android SDK Platform API 26+
- **Native Runtime**: The Go engine pinned in `native-engine.lock.json`, built into `libdsh.so` (see README, "Building from Source")

### Building the Native APK

```bash
# Build the pinned Go engine into app/android/app/src/main/jniLibs/<abi>/libdsh.so
# and regenerate assets/runtime/manifest.json (see README, "Building from Source").

# Build arm64 release APK
bash tooling/build-apk.sh -f arm64 --keep-daemon
```

## Guidelines for Changes

1. **Keep Changes Focused**: Each pull request should address a single, well-defined problem or feature.
2. **Comprehensive Verification**: Ensure existing automated tests pass by running relevant test suites before submitting changes.
3. **Respect Upstream Licenses**: Retain required copyright notices and attributions in accordance with AGPL-3.0 and MIT terms for bundled components.
