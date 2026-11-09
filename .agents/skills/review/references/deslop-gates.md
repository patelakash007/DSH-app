# DSH Deslop Criteria & Taxonomy

This document defines finding types, severity levels, confidence, and deletion proof standards for code reviews.

## Assessment Stages

1. **Candidate**: Duplicate code, single-caller wrappers, empty catches, fallbacks, stale comments, or static scanner warnings indicate areas to inspect, not automatic defects.
2. **Finding**: Concrete observable failure modes, contract violations, or tangible maintenance burdens tied directly to the change under review. Do not categorize based on styling or speculative future problems.
3. **Actionable Item**: Beyond identifying a finding, prove that deletion or consolidation preserves runtime behavior, ownership boundaries, backward compatibility, and test coverage. Without this proof, report or ask for clarification rather than deleting.

## Severity & Entropy Taxonomy

| Category | Criterion | Review Axis |
|---|---|---|
| defect | Concrete incorrect behavior, contract violation, security vulnerability, or redline breach | A–D |
| slop | No proven behavioral defect, but dual maintenance, unbeneficial abstraction, or misleading documentation | E |
| preference | Styling, blank lines, ordering, or phrasing that does not violate explicit rules | Do not report |

- **Blocker (❌)**: Proven substantial defect, security risk, or redline breach that cannot be bypassed.
- **Warning (⚠️)**: Identifiable impact or missing verification. Requires resolution, additional proof, or explicit documented acceptance by maintainers before merge.
- **Suggestion (💡)**: Low-risk maintenance improvement with solid evidence, but not blocking.

Confidence levels: **High** indicates direct causal evidence; **Medium** indicates proven mechanisms with bounded scope. Pure speculation belongs in clarification questions rather than low-confidence findings.

## Proof Standards Prior to Removal or Consolidation

Examine static references, dynamic string registrations, public APIs, side effects, generator sources, test fixtures, and platform branches before deleting code. Zero regex hits does not prove zero callers.

| Candidate | Required Proof |
|---|---|
| Unused symbols or dead paths | Inspect Dart exports, JS package exports, Riverpod providers, platform channels, plugin protocols, and generators. Never delete unverified public consumers. |
| Duplicate helpers | Verify input boundaries, error semantics, lifecycles, and side effects. Establish the single authoritative implementation before migrating callers. |
| Single-caller wrapper | Prove it does not encapsulate resource lifecycles, platform boundaries, or test doubles. |
| Catch / fallback / defensive branch | Prove it swallows genuine errors or duplicates an existing check without distinct reachable failure modes. Never remove cleanup or disconnect guards solely due to branch counts. |
| Comments or documentation | Prove it contradicts current implementation, entry points, or commands. Keep explanations of subtle invariants or platform constraints. |
| Tests or snapshots | Prove removal does not lose invariant or platform coverage. Never relax assertions to disguise failures. |
| Unrelated changes | Demonstrate that the change is orthogonal to the PR objective and increases review/rollback cost. |

## DSH Architectural Boundaries

- Prioritize correctness of user inputs, session logs, request idempotency, and resource ownership before reducing lines of code.
- Flutter UI, pure Dart client, bridge layer, and patched runtime serve distinct architectural roles; do not confuse architectural separation with duplication.
- Start verification with focused regressions, documenting any environment limitations faithfully.
