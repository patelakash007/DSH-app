# Release and Packaging Guide

This guide describes the build, signing, and release procedures for **DSH Native Android**.

---

## 1. Versioning Specification

- **Release Version**: Semantic version `1.0.0` defined in `app/pubspec.yaml` (`version: 1.0.0+1`).
- **Build Number**: Generated dynamically during APK packaging by `tooling/build-apk.sh` based on build timestamp.
- **Git Tag**: Tagged as `v1.0.0` on the `main` branch.

---

## 2. Release Artifacts

The packaging pipeline generates the following release outputs:

| Artifact | Target Architecture | Description |
|---|---|---|
| `app-arm64-release.apk` | `arm64-v8a` | Primary distribution package for standard 64-bit Android smartphones |
| `app-x64-release.apk` | `x86_64` | Package for Android emulators and x86 Chromebook devices |
| `runtime-arm64.tar.gz` | `arm64-v8a` | Native on-device runtime bundle |
| `runtime-x64.tar.gz` | `x86_64` | Native runtime bundle for x86_64 devices |

---

## 3. Build Workflow

### Step 1: Prepare Toolchain
```bash
bash tooling/setup-toolchain.sh
source tooling/env.sh
```

### Step 2: Build Runtime
```bash
# Build native runtime for arm64
bash runtime/build-runtime.sh arm64-v8a
```

### Step 3: Package APK
```bash
# Build arm64 release package
bash tooling/build-apk.sh -f arm64 --keep-daemon
```

### Step 4: Verification
Before publishing a release, verify:
1. Automated tests pass: `python3 -m unittest discover tooling`
2. APK installs and launches cleanly on a test device or emulator.
3. Native engine boots without errors and executes tool approvals properly.
