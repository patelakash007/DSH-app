# Local Market Verification Record

Automated offline test suite results and market package verification records.

| Scope | Result |
|---|---|
| `npm test` (market) | 24 offline tests passed (tarball schema validation, rejection rules, risk tags, native manifests) |
| `npm test -- --maxWorkers=1` (Worker) | 112 tests passed, including regression and route tests |
| `npm run typecheck` (Worker) | TypeScript typecheck passed |
| Workflow checks | check / publish / watch workflows verified |

### Tested Sample Packages:
- `@liustack/modlens` (3.27.2)
- `@liustack/modsearch` (5.10.11)
- `@xmanrui/dsh-im` (5.8.0)
- `dsh-context` (0.78.2)

### Verification Boundaries:
- Manifest paths reject traversal, absolute, or malformed path segments.
- Archive extraction normalizes trailing slashes and enforces deduplication.
