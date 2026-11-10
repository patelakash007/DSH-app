# DSH Repository Redlines

Authoritative sources: AGENTS.md and CONTRIBUTING.md. Severity ratings reflect reviewer governance policy.

## 1. Source vs. Generated Separation | Blocker
Modify source files only; never manually edit build artifacts or generated outputs: `app/build/`, `.dart_tool/`, merged l10n files, or synced guides. Run `python3 app/tool/l10n_merge.py` for `.arb` changes, `python3 app/tool/guide_sync.py` for `docs/guide/` edits, and `node sdk/plugin-kit/scripts/sync-skill.mjs` for plugin skill inputs.

## 2. Engine Patches & Pins Sync | Blocker
The engine revision in `native-engine.lock.json` must stay synchronized with the packaged `libdsh.so` and its manifest hash. Never ship a binary whose hash is not recorded.

## 3. Single Source of Truth for Bridge Protocol | Blocker
`/dsh-go/v1/*` route schemas, response payloads, and error codes (`unavailable`, etc.) are defined authoritatively by the pinned Go engine (`DSH-go-rewrite`). App layers (`packages/dsh_client`, `app/lib/state`) consume without defining parallel sources of truth. Both sides and integration tests must stay synchronized.

## 4. Authoritative Host Answers for Critical Operations | Blocker
Destructive operations (session deletion, permission grants, credential modifications) must rely on real host responses. Never fake answers locally; return stable error codes and avoid silent error suppression.

## 5. Explicit State Ownership | Warning / Blocker
Riverpod provider `autoDispose` lifecycles, mux generations, and connection object ownership must remain unambiguous. Asynchronous callbacks must not revive disposed state.

## 6. Language & Guide Synchronization | Warning
Documentation, guides, and README files must be maintained in clean, professional English.

## 7. Credentials & Privacy | Blocker
Never log, echo, or persist raw API keys, bearer tokens, cookies, or secrets. Scrub all diagnostic logs before sharing.

## 8. Git Safety | Blocker
Stage only explicit file paths; never use blind `git add .`. Do not commit credentials, local test caches, or untracked temporary files.

## 9. Build & Device Verification Contracts | Warning / Blocker
Native builds run via `tooling/build-apk.sh`. Distinguish between desktop simulations and on-device testing. Never claim execution of unrun tests or non-existent commands.

## 10. Scope Discipline | Warning / Blocker
Keep PRs atomic with a single focus. Do not bundle unrelated format churn, speculative dependencies, or stray configs.
