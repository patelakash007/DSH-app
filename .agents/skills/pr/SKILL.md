---
name: pr
description: Open or update a pull request in patelakash007/DSH-app, including authoring its description.
---

Prepare and submit changes as a clean pull request with complete context: why it exists, change outlines, and verification evidence.

1. Ensure each PR has a single distinct focus and links relevant issues.
2. Commit changes using conventional commit style (`type(scope): summary`). Stage only explicit target files.
3. Review the complete diff and gather all actual verification command outputs.
4. Fill in the repository [PR Template](../../../.github/PULL_REQUEST_TEMPLATE.md):
   - **Why the change**: One concise sentence.
   - **Special things to note**: 1–3 reminders for reviewers, including any deliberately unrun checks.
   - **Change outline**: Structural summary and data flow.
   - **Verification**: Exact commands run and output results; clearly distinguishing emulator vs physical device tests.
5. Create or update via `gh pr create` / `gh pr edit` and verify rendered markdown with `gh pr view`.
