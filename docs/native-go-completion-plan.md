# DSH-app Native Go Completion Plan

> Status: working roadmap, 2026-11-10
> Scope: finish the native Go engine, preserve the tested Flutter UI, port every required local capability, migrate user data, and remove the Node/PRoot/Ubuntu fallback from every build path.
> Repositories: [patelakash007/DSH-app](https://github.com/patelakash007/DSH-app) and [patelakash007/DSH-go-rewrite](https://github.com/patelakash007/DSH-go-rewrite).

## 1. Project ambition

The product goal is not merely to produce an APK containing a Go binary. It is to keep the existing DSH-app experience while replacing the simulated Linux computer underneath it with a complete Android-native engine:

- Keep the current Flutter UI, themes, chat experience, Deepy, and Whale Girl visually unchanged.
- Run the local engine as an Android ARM64/x86_64 Go executable, supervised by Kotlin.
- Ship a standalone APK. The installed app must not require Termux, a Termux prefix, a separate terminal app, root, or another runtime package.
- Remove PRoot, the Ubuntu rootfs, Node.js, npm/pnpm, glibc launch shims, and fake-Linux bootstrap code.
- Preserve the behavior users expect: chat, tools, approvals, files, search, terminal, package/plugin management, Git, GitHub, web search, phone control, voice, authentication, schedules, subagents, plugins, and recovery.
- Preserve existing user data through an idempotent, crash-safe migration.
- Do lightweight inspection and focused edits in Termux; run compilation, race tests, Flutter/Gradle work, Android builds, and APK audits on GitHub runners.
- Produce reproducible, permanently signed APKs from pinned source.

The Flutter UI is considered complete and user-tested. This roadmap freezes `app/lib/ui/**` and visual goldens unless a backend contract makes a narrowly scoped UI correction unavoidable. Backend, state, transport, platform-channel, engine, test, build, and documentation work remain in scope.

### Standalone runtime boundary

Termux is allowed only as the maintainer's lightweight development console for Git, small edits, and reading filtered CI logs. It is not part of the product architecture. The release must work after Termux and all Termux packages are uninstalled.

The APK may contain:

- `libdsh.so`, built for the APK's Android ABI.
- Small, audited Android-native helper binaries when a Go implementation is not sufficient.
- App-owned assets, schemas, CA data, skills, migrations, and web resources.
- Optional tool packs downloaded by the app only when they are ABI-matched, signed, hash-verified, licensed, and managed by the app itself.

The APK and its downloaded private data must not execute binaries from `/data/data/com.termux`, `$PREFIX`, a shared Termux directory, or a user-installed Termux package. Tools should run as Go capabilities in the engine whenever possible; a helper process is an exception with an explicit owner, lifecycle, resource budget, and test.

Primary physical acceptance device:

```text
Samsung Galaxy M35
6 GB RAM
Android 17 / One UI 9
arm64-v8a
```

GitHub runners perform heavy compilation and automated tests. This phone performs final installation, lifecycle, thermal, battery, permission, and real-tool acceptance checks.

## 2. What the earlier native-build session actually accomplished

The OpenCode session **“Rebuilding DSH-app for native Android”** established the real native foundation. Its objective was to make core native chat work without deleting the old engine yet, use GitHub for heavy work, and deliver a verified APK.

### DSH-app commits from that session

| Commit | Result |
|---|---|
| `dbfd4ff` | Added the real Dart-client-to-Go contract test, Go 1.25 alignment, Android ELF checks, and fixed a CI syntax blocker. |
| `b577e88` | Made the Dart registry/lock use deterministic in the native contract job. |
| `4023ace` | Added native `workspace/follow` coverage for the session drawer baseline/archive stream. |
| `d835146` | Added stable release-signing setup to the native APK workflow. |

### DSH-go-rewrite commits from that session

| Commit | Result |
|---|---|
| `e3dfd1b` | Fixed the native client/server contract and core mux wiring. |
| `1936998` | Fixed contract races and cloud dependencies. |
| `36924ba` | Added workspace stream and capability contracts. |

### Concrete defects fixed in that session

- Corrected `session/follow`: Dart sends `payload.args.request`; Go had read the wrong nesting level.
- Normalized in-memory message content so a fresh prompt does not disappear from model history.
- Added safer turn ownership, request idempotency, cancellation, and subscriber cleanup.
- Bound login cookies to the request authority.
- Added per-connection mux identities.
- Returned explicit method-not-found failures instead of silent empty success for unknown methods.
- Added basic capability-shaped responses.
- Added `workspace/follow` baseline/archive updates.
- Added Go unit/race, live Dart-Go, Android ARM64, ELF, and 16 KiB page-size checks.
- Produced a native APK containing `libdsh.so` with no Node/PRoot/rootfs in that workflow's artifact.

### What that session deliberately did not finish

- It did not wire the rich Go agent/tool packages into the HTTP/WebSocket server.
- It did not implement full DSH client protocol parity.
- It did not make terminal, Bash, Git, `gh`, web search, package management, files, tools, approvals, phone control, speech, auth, or plugins native-complete.
- It did not migrate legacy rootfs data.
- It did not remove fallback source, Gradle wiring, Kotlin launch paths, old tests, or old documentation.
- It did not build an x86_64 Go engine.
- It did not solve arbitrary Node/Cordis plugin compatibility without Node.

## 3. Honest completion estimate

“About 90%” is fair only for the narrow milestone **“a native ARM64 APK can launch Go and pass a basic chat/workspace contract.”** It is not yet fair for the complete product ambition.

| Area | Current estimate | Notes |
|---|---:|---|
| Flutter UI and visual product | 100% | User-tested; freeze it. |
| ARM64 native build and launch foundation | 85–90% | Go executable launches directly and reaches Flutter through the existing local protocol. Reproducibility and signing isolation still need work. |
| Basic chat/session contract | 75–85% | Core create/follow/prompt/history/cancel paths have contract coverage, but broader semantics remain. |
| Full local RPC/stream parity | 20–30% | The app/client contains about 110 literal RPC methods. The current Go dispatcher recognizes 25; several recognized methods are empty capability placeholders. |
| Real tools and approval pipeline | 10–20% | Rich Go packages exist, but `cmd/dsh-server` still uses a simplified direct model-response path rather than the complete agent/tool loop. |
| Native command/tool ecosystem | 10–20% | Search, shell, Git, `gh`, web search, package manager, terminal, and supporting binaries need implementation and conformance tests. |
| Native phone/auth/speech/plugin bridges | 10–20% | Kotlin still prepares legacy patch overlays that the native branch does not consume. |
| User-data migration | 5–10% | Legacy and native stores coexist; no complete journaled importer exists. |
| Legacy source removal | 20–30% | The dedicated native artifact excludes legacy payloads, but repository code and other build paths still retain them. |
| Whole native product ambition | **45–55%** | The foundation is real; feature parity, migration, and deletion are the larger remaining work. |

These percentages are progress indicators, not release claims. A feature counts as complete only after a semantic contract test and an Android smoke test pass.

## 4. Current architecture and gap

The working native path is:

```text
Flutter UI (unchanged)
    -> packages/dsh_client
    -> authenticated HTTP + WebSocket on 127.0.0.1
    -> Kotlin lifecycle/process supervisor
    -> libdsh.so (Android Go executable, separate child process)
```

Keeping Go out of the Flutter process is acceptable and desirable: it is still native and provides crash isolation. The project should describe it as an **out-of-process native Go engine**, not JNI or an in-process shared library.

The main gap is not Flutter-to-Kotlin wiring. It is that `cmd/dsh-server` exposes only a small compatibility server and does not yet drive the complete engine behavior expected by the existing UI.

## 5. Findings and bugs to fix

### P0 — Release signing material is exposed too early

`.github/workflows/build-native-apk.yml` currently writes the keystore and passwords before running code from an unpinned external repository. Mutable action tags also run after the key is present. The workflow runs on every push and is independent of full CI.

Required fix:

1. Test and build unsigned artifacts in a job with no signing secrets.
2. Pin `DSH-go-rewrite` to an exact commit and pin every action by SHA.
3. Use `permissions: contents: read` and `persist-credentials: false`.
4. Pass the tested APK/AAB to a separate protected signing job/environment.
5. Sign only successful `main`/release-tag builds.
6. Add `**/*.p12` to ignore rules.
7. Verify the final signer fingerprint against a pinned expected fingerprint before upload.

### P0 — Native engine provenance is not reproducible

The tracked `libdsh.so` reports a dirty external source revision, while CI builds a moving external default branch. The native manifest does not contain the source commit or binary hash.

Required fix:

- Make Go source a pinned build input: submodule, subtree, or an `engine.lock` with repository and commit.
- Reject dirty builds.
- Generate a native manifest containing source repository, source commit, engine/protocol version, ABI, SHA-256, and capabilities.
- Build both supported ABIs from the same source revision.
- Do not commit opaque replacement binaries unless their source and reproducible recipe are recorded.

### P0 — Required upstream attribution is missing

The native binary identifies `github.com/JopenChen/dsh-go`, whose upstream license contains the JopenChen MIT notice. It is not listed in `THIRD_PARTY_NOTICES.md` or the in-app `LicenseRegistry`. A dirty binary also prevents exact corresponding-source reconstruction.

Required fix:

- Add the upstream project, copyright, MIT text, source revision, fork/modification notice, and binary provenance to `THIRD_PARTY_NOTICES.md`.
- Add the same notice to the in-app licenses.
- Preserve AGPL obligations for the fork and make exact corresponding source available for every distributed engine binary.

### P1 — Native server protocol is far from parity

- Roughly 110 literal RPC methods are used across the Dart client/app.
- The current Go dispatcher recognizes 25.
- Some recognized methods intentionally return empty lists or non-writable placeholders.
- Only a small stream set is implemented.

No UI surface should be called complete because a placeholder avoids an exception. It must return correct data and behavior.

### P1 — The real Go agent/tool engine is not wired to the server

The Go repository contains agent, tool, approval, goal, plan, skill, subagent, workflow, sandbox, and persistence packages. The server still performs a simplified model call and text stream. Tool calls, approvals, retries, steering/queueing, and full event semantics need to use those packages.

### P1 — Native launch silently ignores legacy integrations

Kotlin prepares phone, message-search, subscription-auth, speech, storage-bind, safe-mode, and last-known-good inputs. The early native branch of `DshProcess.start()` does not consume those patch/overlay arguments. Each needs an explicit native protocol instead of a rootfs patch.

### P1 — Native paths still pretend `/root` exists

Examples include:

- Default workspace: `/root/workspace`
- DSH home: `/root/.dsh`
- Agents home: `/root/.agents`
- Flutter and Kotlin readers rooted at `filesDir/runtime/rootfs`

The Go engine currently uses `filesDir/dsh_home`. Introduce one native path contract and remove guest-path assumptions before deleting the rootfs.

### P1 — No native x86_64 engine is packaged

The app advertises an x64 flavor, but the checked-in native engine is ARM64. Build and contract-test `GOARCH=amd64` or explicitly drop x64 support. “No breakage” means keeping it.

### P1 — Existing Node plugins cannot run after Node removal

Current Cordis/DSH plugins are JavaScript packages and may use `node:fs`, `node:crypto`, npm dependencies, and Node host APIs. It is impossible to remove Node and promise arbitrary existing Node plugins run unchanged without a compatibility runtime.

The final native design must therefore provide a migration target—preferably a versioned WASI/Go/process-neutral plugin ABI—and keep the old path only during the migration window. Do not claim plugin parity until supported plugins have actually migrated.

### P2 — Android denies hard links used by legacy direct mode

Android app-private storage returned `EACCES` for a same-directory hard link. Legacy session deletion and media publication require `link()`, and one existing fallback explicitly excludes `EACCES`. This confirms that legacy direct-glibc mode is not a safe long-term fallback.

### P2 — Local release instructions can produce an unusable unsigned APK

The current working-tree signing change correctly avoids implicit debug signing, but documented local commands still default to release mode without explaining keys or an explicit local debug-signing option.

Required fix: fail fast without a release key, add a documented explicit local-test signing flag, and keep production signing isolated.

## 6. Native capability parity matrix

Every row needs a native implementation, semantic contract tests, and an Android smoke test before fallback removal.

| Capability | Current state | Native target | Completion evidence |
|---|---|---|---|
| Core chat | Partially wired and cloud-tested | Complete session lifecycle, streaming, retries, cancellation, queue/steer, compaction, persistence | Dart-Go transcript tests plus restart/reconnect tests |
| Agent tools | Go packages exist; server loop is simplified | Wire the real Go agent/tool/approval pipeline | Model-issued tool call, approval, result, retry, cancellation traces |
| Local file tools | Incomplete | Go-native read/write/edit/list/glob with canonical-path confinement and budgets | Traversal, symlink, race, large-file, cancellation tests |
| Local text/code search | Legacy tools/rootfs assumptions | Go walker/searcher with ignore rules, Unicode, binary detection, result budgets | Compare fixtures with expected grep/search behavior |
| Session search | Basic SQLite search exists | Durable indexed title/content search with pagination and Unicode behavior | Restart, archive, Chinese/English, stale-index tests |
| Web search | Not wired in native server | Go HTTP provider adapters, timeout/cancel/rate limits, normalized citations | Mock-provider contract and one opt-in live CI test |
| Shell/terminal | Legacy Linux userland expected | Native PTY/process service using `/system/bin/sh` and an explicit Android-native toolbox | Interactive PTY, resize, UTF-8, timeout, process-tree cleanup tests |
| Bash compatibility | Ubuntu Bash disappears | Prefer Go-native tools; bundle an Android-native Bash only if exact Bash is a required product contract | Real-device command corpus |
| Git | Ubuntu/Termux Git previously available | Implement common operations with `go-git` or package a verified Android-native Git tool | clone/status/diff/branch/commit/push against local fixtures |
| GitHub (`gh`) | Not available natively | Go GitHub REST/GraphQL tool or verified native `gh` binary; credentials stay in secure storage | Mock API tests and opt-in repository smoke test |
| Package manager | Node/npm/Cordis path | Split native tool-pack management from plugin management; signed metadata, hashes, rollback | Install/update/remove/offline/corruption tests |
| Plugin manager | Placeholder responses | Native plugin ABI, inventory, configuration, lifecycle, migration diagnostics | Port first-party examples and run their existing behavior corpus |
| Workspace/files | Partial workspace stream only | Files, uploads, attachments, references, directory picker, artifacts, export | Dart API contract plus Android SAF/shared-storage tests |
| Models/providers | Mostly DeepSeek-only | Provider discovery/config, custom providers, credentials, model selection, usage/errors | Provider mock matrix and credential round trips |
| Account/subscription auth | Legacy JS overlay ignored | Typed Go/Kotlin auth bridge with browser/poll/answer/cancel/sign-out | Fake OAuth/subscription server tests |
| Phone control | Kotlin service exists; Node relay/patch is legacy | Go registers phone tools directly and talks to authenticated Kotlin bridge | Full screen/action/approval/handoff device suite |
| Voice/speech | Legacy Node/native-addon path | Kotlin native service or Go/native bindings; preserve model lifecycle and cancellation | Model prepare/transcribe/cancel/memory recovery tests |
| Skills | File layout assumes rootfs | Native home/agents-home discovery and managed atomic installation | Existing skill corpus against native paths |
| Safe mode/LKG | Built around Cordis profiles/rootfs | Rescue home or `--safe`, plugins/tools disabled as intended, native config preflight/LKG | Fault injection, probation, restore, crash-loop tests |
| Schedules/jobs/goals/subagents | Client methods exist; native server incomplete | Wire existing Go packages and durable state | Restart, cancellation, parent/child, time-zone tests |
| Embedded DSH Web | Go root serves health, not full web UI | Embed/serve compatible web assets or a native-engine web bundle without changing Flutter layout | Local WebView login/navigation/plugin smoke test |
| Media/PDF | Legacy Node modules or missing RPCs | Port required transforms to Go/Android libraries | Golden metadata and bounded-file tests |
| Permanent deletion | Minimal Go route exists | Preserve all active-task, relationship, durability, and retry safety guarantees | Power-loss and concurrent-writer deletion suite |

## 7. Work plan

### Phase A — Secure and pin the release pipeline first

Focus:

- Fix signing isolation and workflow permissions.
- Pin engine source and action SHAs.
- Add `concurrency`, branch/tag filters, and timeouts.
- Make full native contract success a prerequisite for signing.
- Generate provenance and checksums.

Heavy work: GitHub runner.
Phone work: YAML review, `git diff --check`, commit/push.
Exit gate: an untrusted engine test cannot read signing material; one app commit always selects one engine commit.

### Phase B — Freeze a complete machine-readable contract

Add a generated inventory of:

- Dart RPC methods
- mux streams
- HTTP/file routes
- event variants
- stable errors
- feature/capability flags

CI must fail when the client adds a route without native support classification and a test.

Exit gate: every app-callable local method is `implemented`, `in-progress`, or `blocked` with an owner and test—not silently absent.

### Phase C — Build clean native binaries for both ABIs

- Build ARM64 and x86_64 from the pinned clean engine revision.
- Verify ELF machine, `/system/bin/linker64`, page alignment, stripped symbols, source metadata, and hash.
- Remove the dirty checked-in binary once reproducible local/cloud generation is dependable.
- Keep the Go engine as a child process for isolation; JNI is not required.

Exit gate: both flavor APKs start the same protocol version and pass the same contract suite.

### Phase D — Introduce native backend and path contracts

Create Kotlin concepts such as:

```text
EngineBackend
  NativeGoBackend
  LegacyBackend          // temporary only

NativeRuntimePaths
  home
  agentsHome
  workspaceRoot
  tempRoot
  logs
  phoneStorageRoot
  legacyRootfs           // migration input only
```

Refactor backend/state code, not visual UI. Replace hard-coded `/root` and `runtime/rootfs` consumers in sharing, UI config, skills, voice assets, read-list identity, artifact resolution, diagnostics, and workspace creation.

Exit gate: native mode starts and passes tests when `filesDir/runtime/rootfs` does not exist.

### Phase E — Wire the real Go agent and core protocol

- Replace the simplified direct provider call with the real agent loop.
- Implement durable session metadata and event restoration.
- Add tools, approvals, questions, queue/steer, retries, goals, todos, subagents, and cancellation.
- Implement all session/workspace streams with bounded queues and reconnect behavior.
- Persist archive/pin/folder/model/cwd state across restart.

Exit gate: no core-chat or session-management screen receives a placeholder response; golden legacy/native event transcripts agree where behavior should remain compatible.

### Phase F — Port the tool ecosystem

Implement one focused tool family per PR:

1. Native filesystem operations and local search.
2. Process execution and PTY lifecycle.
3. Web fetch and web search.
4. Git operations.
5. GitHub operations.
6. Native package/tool-pack management.
7. Attachments, uploads, artifacts, PDF/media.
8. Schedules, jobs, goals, and subagents.

Do not solve command availability by restoring Ubuntu. Prefer Go implementations. Where a real executable is necessary, package a small audited Android-native binary with a hash and license, then execute it from Android's extracted native-library directory.

Exit gate: the native tool matrix has unit, integration, and Android smoke evidence.

### Phase G — Replace legacy overlay bridges

- Phone: register tools in Go and connect directly to the authenticated Kotlin bridge; delete `relay.cjs` and patch YAML only after parity.
- Search: use native SQLite/FTS behavior.
- Auth: expose native Go/Kotlin RPCs.
- Speech: move worker/model ownership to Kotlin or native Go bindings.
- Safe mode: use a rescue home/native capability policy, not a Cordis patch profile.
- Embedded web: serve compatible assets from the Go engine.

Exit gate: native startup consumes no `--patch`, rootfs bind, Node relay, or generated guest file.

### Phase H — Migrate plugins without pretending Node compatibility

1. Define the native plugin ABI and capability model.
2. Port the bundled bridge behavior and first-party examples.
3. Implement a checker/migration report for installed Node plugins.
4. Port supported market plugins or provide documented replacements.
5. Preserve manifests/view JSON where possible.
6. Keep the fallback only during this compatibility window.

Exit gate: every plugin category promised for local use runs without Node. Arbitrary unsupported Node packages are explicitly identified before cutover, never silently ignored.

### Phase I — Crash-safe data migration

Migration sources may include:

```text
filesDir/runtime/rootfs/root/.dsh
filesDir/runtime/rootfs/root/.agents
filesDir/runtime/rootfs/root/workspace
filesDir/dsh_home
```

Implement a durable state machine:

```text
notNeeded -> pending -> scanning -> importing -> verifying -> complete
                                               -> failed/retryable
```

Requirements:

- Engine stopped during committed migration steps.
- Read-only legacy source.
- Preserve IDs, timestamps, event order, forks, subagents, archives, pins, models, and cwd.
- Merge without overwriting newer native data.
- Stream large histories.
- Never log credentials.
- Verify counts and digests.
- Resume safely after process death at every step.
- Keep legacy data until native start, historical-chat open, and export checks pass.
- Offer cleanup later; never automatically erase the only copy.

Exit gate: fixtures from every released legacy format survive forced termination during each migration stage.

### Phase J — Native-only canary, then legacy deletion

Release progression:

1. Dual code, native-only internal flag, no automatic fallback.
2. Beta uses native only; legacy data remains available for rollback.
3. Stable native-only release with migration complete.
4. Remove legacy payloads and build paths.
5. Keep only the small legacy-data importer for a support window.
6. Later remove the importer after an explicit compatibility decision.

Final deletion list includes:

- `runtime/build-runtime.sh`
- Ubuntu, npm, and pnpm locks
- runtime patches and Node bridge/media host code
- PRoot/direct-glibc scripts and tests
- `DirectLaunch.kt`
- `L2sMigration.kt`
- `ProotTempFiles.kt`
- rootfs extraction/upgrade code in `RuntimeInstaller.kt`
- `TarExtractor.kt`, `ParallelXZInputStream.kt`, and XZ dependency
- PRoot/talloc/shmem JNI packaging
- legacy sections of `DshProcess.kt` and process ownership
- rootfs patch generators after native replacements exist
- obsolete direct/fallback status fields and documentation, while preserving the existing UI layout

Keep:

- Flutter UI
- Kotlin foreground service and process supervision
- `libdsh.so`
- authenticated loopback protocol
- Android platform bridges
- runtime logs/crash classification adapted to native Go
- migration code until the support window ends

## 8. Lightweight Termux and cheap-AI workflow

### Work that should stay on the phone

- Read/search a small set of named files.
- Edit one focused subsystem.
- `git status`, `git diff`, `git diff --check`.
- Small Python/Node schema or generator checks already available locally.
- Commit and push.
- Read filtered GitHub failure logs.

Avoid on the phone unless narrowly required:

- Flutter builds/tests.
- Gradle builds.
- Go race detector.
- Cross-ABI Go builds.
- Android emulator/device farms.
- Full monorepo test runs.
- Rootfs/runtime builds—the final project should delete these entirely.

### GitHub runner jobs

Use path-filtered, cancellable jobs:

```text
contract-inventory       Fast static client/server coverage check
go-unit                  Go unit tests
go-race                  Race detector
dart-go-contract         Real DshClient against real Go server
tool-conformance         Search/files/shell/git/gh/web/package fixtures
migration                Legacy fixtures + power-loss/resume simulation
native-build             ARM64 and x86_64 matrix
android-jvm              Kotlin runtime/bridge tests
flutter                  Existing UI/state tests; no visual redesign
apk-audit                No legacy files; ABI, pages, licenses, hashes
sign                     Protected final job, no untrusted code execution
```

Use caches for Go modules, Flutter, Gradle, and Android SDK components. Use `concurrency` to cancel obsolete branch builds. Upload filtered diagnostics on failure rather than asking a phone-side AI to process full logs.

### Cheap-AI task packet

Never ask one inexpensive model to “finish native DSH.” Give it one bounded packet:

```text
Goal:
Exact files allowed:
Contract/API being implemented:
Current failing test or missing behavior:
Required edge cases:
Commands GitHub CI will run:
Files that must not change: app/lib/ui/**, goldens, unrelated user work
Definition of done:
```

Prefer tasks that fit in one reviewable commit. If a task needs more than one protocol family, split it.

## 9. Required final acceptance gates

### Product behavior

- [ ] Existing Flutter UI and visual goldens remain unchanged.
- [ ] The APK installs and runs on the Samsung M35 with Termux absent/uninstalled.
- [ ] No runtime path, subprocess, tool, or package manager reads from a Termux prefix.
- [ ] Cold start and restart work offline up to provider access.
- [ ] Chat, streaming, history, cancellation, queue/steer, and reconnect work.
- [ ] Tools and interactive approvals work.
- [ ] Files, attachments, workspace, terminal, and artifacts work.
- [ ] Local search and web search work.
- [ ] Git and GitHub operations work.
- [ ] Native package/plugin management works for the supported native ABI.
- [ ] Phone control, auth, speech, safe mode, and diagnostics work.
- [ ] Schedules, jobs, goals, and subagents survive restart.
- [ ] Embedded DSH Web works if the product continues to expose it.
- [ ] Permanent deletion is durable and race-safe.
- [ ] ARM64 and x86_64 behave consistently.

### Device resource and thermal acceptance

Record the old-runtime baseline and native result under the same network, model, prompt corpus, brightness, and battery conditions. Do not claim performance from desktop CI alone.

- [ ] Measure tap-to-listening cold and warm startup time; investigate any native cold start above the project's two-second target.
- [ ] Record engine and whole-app proportional set size after start, one idle chat, a tool-heavy turn, and 15 minutes idle.
- [ ] Run a 30-minute mixed chat/tool workload without thermal runaway, restart loops, or unbounded memory growth.
- [ ] Compare battery drop and device thermal status with the old PRoot/Node build using the same workload.
- [ ] Bound Go concurrency and background workers for a 6 GB phone; cancel idle workers and release voice/media models after use.
- [ ] Verify foreground/background behavior under Samsung battery management and after process kill/relaunch.
- [ ] Keep the measurements as release artifacts with app/engine commits and device build identifiers.

### Upgrade safety

- [ ] Legacy sessions and metadata migrate with IDs and timestamps intact.
- [ ] Skills, settings, credentials, and workspace files are preserved.
- [ ] Migration resumes after forced termination.
- [ ] Conflicts never overwrite newer native data.
- [ ] A verified export/backup exists before optional legacy cleanup.

### APK audit

The final APK must contain none of:

```text
rootfs-*.tar.*
node
npm
pnpm
ubuntu
libproot.so
libproot-loader.so
libtalloc.so
libandroid-shmem.so
```

The final runtime process list must show the app and native Go engine, with no Node or PRoot process.

### Release integrity

- [ ] Pinned clean engine source and action SHAs.
- [ ] Full contract passes before signing.
- [ ] Signing isolated in a protected job.
- [ ] Expected signer fingerprint verified.
- [ ] Engine source commit and binary hash published.
- [ ] Complete AGPL/MIT notices and corresponding source available.

## 10. Immediate execution order

Do not start by deleting `runtime/`. Start with these focused PRs:

1. **Secure and pin native build/signing.**
2. **Generate the complete RPC/stream/route parity inventory.**
3. **Create clean ARM64+x86_64 native build outputs and provenance manifest.**
4. **Introduce `NativeRuntimePaths` and remove `/root` assumptions from backend/state code.**
5. **Wire the real Go agent/tool/approval loop.**
6. **Port native files/search/shell, then Git, `gh`, web search, and package management.**
7. **Replace phone/auth/speech/search/safe-mode overlays.**
8. **Migrate plugins and user data.**
9. **Run native-only beta without automatic fallback.**
10. **Delete Node/PRoot/Ubuntu and prove their absence from every APK/build path.**

The legacy-removal commit should be the final small consequence of completed parity—not the mechanism used to discover missing features.
