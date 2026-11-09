# Review Report Contract

Unless machine-readable JSON is explicitly requested, review reports must adhere to the following markdown structure:

```markdown
# Review verdict
**Verdict**: Request changes | Merge with conditions | No blocking findings
**Mode**: Review | Deslop report | Deslop apply; **Target**: PR/branch/range/absolute path
**Baseline**: latest target `<sha>`; **Head**: `<sha>`
**Trust Level**: trusted-maintainer | trusted-local | untrusted-fork

## Findings
### R1 [❌|⚠️|💡] [defect|slop] [A|B|C|D|E] Title
- **Location**: Absolute path and line numbers (head `<sha>`)
- **Mechanism**: Input/State -> Call chain -> Defect outcome or maintenance entropy
- **Evidence**: Code inspection, search, rule violation, or test command outputs
- **Impact**: User impact, data integrity, contract break, security, or maintenance cost
- **Confidence**: High | Medium
- **Minimal Fix**: Targeted fix preserving existing scope
- **Verification**: Invariants to test following the fix
- **Deletion Proof**: Required for slop; static references, dynamic registries, and side effects

## Clarifying questions
- **Q1**: Missing facts required to confirm or dismiss suspected issues.

## Validation record
| Check | SHA | Result | Coverage / Limitations |
|---|---|---|---|
| `command` or static check | `...` | pass / fail / not run | ... |

## Coverage and residual risk
- Reviewed: ...; Excluded: ...; Limitations: ...; Residual uncertainty: ...

## Merge Conditions
1. Verifiable condition 1.
2. Verifiable condition 2.
```

## Verdict Rules
- Any unresolved ❌ Blocker -> `Request changes`.
- No ❌ Blockers but unresolved ⚠️ Warnings or missing verification -> `Merge with conditions`.
- No blocking findings -> `No blocking findings`.

## Finding Rules
Order by impact rather than discovery order; group identical root causes. Document exact file paths, line numbers, and commit SHAs. Do not report stylistic preferences as findings unless violating explicit repository redlines.
