# DSH Architecture Specification

> Architecture documentation for the DSH Native Android v1.0.0 Release.

## Technology Stack

| Layer | Selection | Rationale |
|---|---|---|
| **Frontend UI** | Flutter (Dart `^3.13.5`) + Riverpod | High-performance reactive UI with responsive layouts across phones and tablets. Consistent rendering across diverse Android OEM skins. |
| **Platform Bridge** | Kotlin (Android platform channels) | Lifecycle management, accessibility service bridge for phone control, foreground services, and native process supervisor. |
| **DSH API Client** | `packages/dsh_client` (Pure Dart) | Platform-independent HTTP and WebSocket communication layer, shared between native on-device and remote host modes. |
| **Remote Gateway** | `packages/dsh_remote` (Pure Dart) | Seamless connectivity to remote DSH server instances via SSH and DSH Remote protocols. |
| **Native Runtime** | Out-of-process Android Go executable (`libdsh.so`) | DSH-Go native engine, pinned in `native-engine.lock.json` and hash-verified at launch. No PRoot, Ubuntu chroot, Node.js, or container layer ships in the APK. |

## Repository Architecture

```text
DSH-app/
  app/                         Flutter application package (dsh_app)
    lib/
      main.dart / app.dart     Entrypoint, theme initialization, routing
      runtime/                 Native runtime controller and process monitors
      state/                   Riverpod providers: endpoints, sessions, settings
      ui/
        theme/                 Material Design with dynamic wallpaper color adaptation
        shell/                 Navigation shell, adaptive layout, drawer
        onboarding/            First-launch setup: local runtime or remote host
        chat/                  Conversational UI: message list, folding, input bar
        sessions/              Session management drawer and timeline search
        settings/              Comprehensive settings interface
        phone/                 Phone control overlay and security gates
        pets/                  Mascot animation widgets and desktop floating window
        plugins/               Native plugin card renderers and slot views
        web/                   Integrated web interface dual-view
    android/                   Native Android Kotlin implementation
      app/src/main/kotlin/     Platform channel handlers, accessibility, notifications
  packages/
    dsh_client/                Pure Dart client for DSH Web API
    dsh_remote/                Pure Dart client for DSH Remote endpoints
  native-engine.lock.json      Pinned Go engine repository, revision, and protocol version
  sdk/plugin-kit/              Plugin authoring kit for native Android tool cards
  examples/plugins/            Sample plugins and UI widgets
  docs/                        Documentation and developer specifications
  tooling/                     Toolchain setup, APK packaging, and diagnostic scripts
```

## Platform Targets

- `minSdk = 26` — required by `java.nio.file` and the native engine's process/path APIs.
- `targetSdk = 28` — deliberate. DSH is distributed as a signed APK from GitHub Releases, not through Google Play, and targets the behavior its privileged phone-control and accessibility integrations were validated against. The trade-off (opt-in to pre-29 background, storage and foreground-service behavior) is accepted for this distribution model.

## Security & Runtime Boundaries

- **Local Confinement**: The on-device engine operates with least-privilege sandboxing within the application sandbox.
- **Permission Elevation**: Sensitive actions (file modifications, phone control gestures, terminal commands) are gated by explicit interactive user confirmation by default.
- **Encrypted Sharing**: Links and replay packages are encrypted client-side; keys are embedded in URL fragments and never exposed to relay infrastructure.
