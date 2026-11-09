export function closeMessage({ locale, prAuthor, repoUrl } = {}) {
  const lines = [
    `Hi @${prAuthor}, thanks for your interest in DSH.`,
    '',
    'DSH currently does **not accept external pull requests** (code, docs, configuration, or templates), so this PR is being closed automatically.',
    'Your branch is yours to keep or delete; closing only reflects the repository policy.',
    '',
    `For feature ideas, improvements, or bug reports, please open an issue: ${repoUrl}/issues/new/choose`,
    'Describe the use case and expected behavior; for bugs, include the app version, Android version, device model, and minimal reproducible steps.',
    '',
    'If the maintainer explicitly wants this implementation, they can reopen the PR; reopening by anyone else will be closed again.',
    '',
    `Policy: ${repoUrl}/blob/main/CONTRIBUTING.md and ${repoUrl}/blob/main/AGENTS.md`,
  ]
  return lines.join('\n')
}
