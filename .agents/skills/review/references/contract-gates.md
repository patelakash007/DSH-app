# DSH Contract Gates

Authoritative sources: the pinned Go engine (`DSH-go-rewrite`) HTTP routes, `packages/dsh_client` public API, `app/lib/state` capabilities, `app/lib/l10n/parts/*.arb`, `sdk/plugin-kit`, and CONTRIBUTING.md. Contract changes lacking backward compatibility, migrations, or tests are rejected by default.

## Gate 1 | Bridge HTTP Contract
`/dsh-go/v1/*` routes: paths, methods, auth rejection, status codes, JSON payload shapes, version fields, and error codes (`unavailable`, etc.).
Blocker: Modifying route/shape/error codes unilaterally on one side without updating the other; missing migration logic; unverified connection-failure or host-rejection paths.

## Gate 2 | Client Public API
`packages/dsh_client` public exports (carrier, mux, SessionDeletionApi, etc.) signature/semantic changes require migration and tests. Never bypass carrier to spawn unauthorized HTTP clients.

## Gate 3 | Capability Tri-State
Host capabilities (e.g. session deletion) must distinguish `unknown` / `supported` / `unsupported`. Disconnected state or unready mux must remain `unknown` rather than collapsed to `false`. Re-probe when mux becomes ready.

## Gate 4 | Runtime Patches & Pins
The revision in `native-engine.lock.json` must match the packaged `libdsh.so` and its manifest hash; engine changes ship with contract tests.

## Gate 5 | Localization & Documentation
`app/lib/l10n/parts/*.arb` must be valid (`l10n_merge.py --check`); `docs/guide/` synchronized with in-app skills (`guide_sync.py --check`); documentation maintained in clean English.

## Gate 6 | Plugin SDK Consumer Surface
`sdk/plugin-kit` public API, skill inputs, and generated files synchronized (`sync-skill.mjs --check`). Missing typecheck dependencies must never be marked as passing.

## Verification of Gate Self-Modifications
When modifying both implementation and protection gates simultaneously, prove with an independent oracle that protection was not weakened.
