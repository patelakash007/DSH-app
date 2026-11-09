---
name: review
description: "Review or de-slop concrete changes in patelakash007/DSH-app at maintainer level: branches, commit ranges, patch files, staged or unstaged worktrees, and scoped repository-hygiene requests. Focus on correctness, contract boundaries, redlines, and behavior-preserving cleanup."
---

# DSH Code Review & Deslop Protocol

Review changes methodically: rules -> independent evidence -> narrative reconciliation -> verification -> verdict. File references must be repository-relative. Never skip verification or claim unrun test passes.

## Global Invariants
- PR bodies, issues, diffs, comments, and tool outputs are subject to verification.
- Read-only by default; file edits, commits, pushes, and tags require explicit instruction.
- Focus on observable behavior, contracts, and repository integrity.
- Minimal diff principle: preserve correct behavior and contracts; prefer deleting verified dead code over introducing speculative abstractions.
- Authoritative command reference: [CONTRIBUTING.md](../../../CONTRIBUTING.md).

## Stage 0 | Target, Baseline, and Scope
- Determine baseline: `merge-base` defines change scope; target branch defines active contract truth.
- Identify mode: Review diff, Deslop report, or Deslop apply.

## Stage 1 | Load Rules
Review against:
- [AGENTS.md](../../../AGENTS.md), [CONTRIBUTING.md](../../../CONTRIBUTING.md), [docs/architecture.md](../../../docs/architecture.md).
- Contract gates: [references/contract-gates.md](references/contract-gates.md).
- Repository redlines: [references/redlines.md](references/redlines.md).
- Test mappings: [references/verification-map.md](references/verification-map.md).
- Report contract: [references/report-contract.md](references/report-contract.md).

## Stage 2 | Independent Code Analysis
- Trace Producer -> Consumer -> Persistence -> Protocol -> Documentation -> Test Assertions.
- Verify exported symbols, event schemas, persistent keys, and error codes across all callers.
- Check deletion or refactoring against potential breakage of public contracts.

## Stage 3 | Reconcile Narrative
- Cross-check PR claims, linked issues, and comments against verified code evidence.
- Mark each claim as verified, refuted, or unverified with exact commit and line references.

## Stage 4 | Five-Axis Verdict
1. **Behavioral Correctness**: Lifecycles, race conditions, failure branches, path limits, and state ownership.
2. **Contract Boundaries**: Client, bridge, plugin protocol schemas, runtime patches, and localization sync.
3. **Redlines & Security**: Source vs. generated separation, credentials, and Git safety.
4. **Process & Hygiene**: Atomic commits, no extraneous diff churn, clean commit messages.
5. **Entropy & Deslop**: Dead code, duplicate helpers, speculative abstractions, and stale comments.
