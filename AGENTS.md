# AGENTS.md

DSH is an Android native client and runtime for DeepSeek Harness: a native Flutter UI, pure Dart clients, and an on-device native Go engine runtime. Before making changes, consult [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/architecture.md](docs/architecture.md).

## Repository Layout

```text
app/                         Flutter App: Native UI, Riverpod state management, phone control
app/lib/l10n/parts/          UI localization ARB template inputs
packages/dsh_client/         Pure Dart client: HTTP/SSE streaming, multiplexing, session APIs
packages/dsh_remote/         Remote gateway transport: WebRTC, LAN, and relay connections
runtime/                     Native runtime assets, engine bridge, and lifecycle management
sdk/plugin-kit/              Plugin authoring SDK for custom tool widgets and cards
tooling/                     Toolchain management, APK packaging, and diagnostic scripts
docs/                        Architecture specifications, guides, and release documentation
```

## Verification Commands

Select relevant verification commands based on the affected scope:

```bash
(cd app && flutter pub get && flutter analyze && flutter test)      # Flutter app checks
(cd packages/dsh_client && dart pub get && dart analyze && dart test) # Dart API client
(cd packages/dsh_remote && dart pub get && dart analyze && dart test) # Dart Remote client
(cd sdk/plugin-kit && npm install && npm test)                       # Plugin kit tests
python3 -m unittest discover tooling                                 # Tooling unit tests
```

## Engineering Rules

1. **Focused Diffs**: Solve the specified problem without unnecessary refactors or broad formatting drift.
2. **Never Weaken Existing Tests**: Do not delete, skip, or modify tests to pass artificially.
3. **Native Direct Execution**: Do not reintroduce containerized PRoot or Ubuntu chroot layers. All on-device components execute directly as native binaries.
4. **License & Attribution Integrity**: Retain AGPL-3.0 and MIT license headers and attribution notices.
