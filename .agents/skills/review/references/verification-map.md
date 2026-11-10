# DSH Verification Map

Authoritative source: CONTRIBUTING.md common checks, tooling scripts, and `.github/workflows`.

## Strict Execution Honesty
Record only executed commands, exit codes, git commit SHAs, and key outputs. Never mark unrun tests as passed. If missing device, dependencies, or engines, explicitly state "not run" and explain the cause.

## Area of Change -> Verification Target
| Subsystem | Minimal Check |
|---|---|
| `app/lib/` UI / State / Riverpod | `(cd app && flutter analyze)` + focused `flutter test test/<target>` |
| `app/` ARB Localization | `python3 app/tool/l10n_merge.py --check` |
| `packages/dsh_client` | `(cd packages/dsh_client && dart analyze && dart test)` |
| `packages/dsh_remote` | `(cd packages/dsh_remote && dart analyze && dart test)` |
| Engine HTTP routes | `native_contract_inventory.py --check` plus the Dart↔Go contract job |
| Engine revision | `native-engine.lock.json` matches the packaged manifest hash |
| `sdk/plugin-kit` | `(cd sdk/plugin-kit && npm test)` + `node sdk/plugin-kit/scripts/sync-skill.mjs --check` |
| `docs/guide/` | `python3 app/tool/guide_sync.py --check` |
| `tooling/` build scripts | `tooling/build-apk.sh` or targeted test suite `python3 -m unittest discover tooling` |
| `.github/workflows` | permissions, fork trust, fail-closed behavior, path filters |
| `.agents/skills/` | YAML frontmatter, relative references, script self-test |

## Test Validity & Anti-False-Green Checks
1. **Failing Baseline**: Confirm tests fail prior to the fix.
2. **Independent Oracle**: Do not calculate expected results using the implementation under test.
3. **Real Codepaths**: Test actual runtime entry points rather than trivial mocks whenever possible.
4. **CI Integration**: Verify test commands are active in automated CI workflows.
