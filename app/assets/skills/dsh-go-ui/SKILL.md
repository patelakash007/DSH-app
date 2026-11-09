---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-ui
description: Configuration of the DSH mobile native UI via $DSH_HOME/dsh-go/ui.json. Customize header actions, quick action capsules, suggestions on new chat screens, drawer grouping and sorting, density, theme accents, and keyboard shortcuts.
whenToUse: The user wants to customize the native DSH Android UI layout, buttons, theme, or quick actions.
---

# DSH Interface Configuration (ui.json)

The DSH app reads configuration from `$DSH_HOME/dsh-go/ui.json` (`DSH_HOME` defaults to `~/.dsh`) and updates its native Flutter UI within 1–2 seconds without restarting.

The file is purely declarative and cannot execute code: no scripts, no network requests. Buttons trigger predefined client actions upon direct user taps.

## Guidelines

1. Read existing config first: `$DSH_HOME/dsh-go/ui.json`. If missing, create parent directories with `mkdir -p`.
2. Modify only requested keys and preserve existing user settings.
3. Output strict JSON: UTF-8, no comments, no trailing commas, maximum size 64 KiB.
4. Validate with: `node "$DSH_HOME/skills/dsh-go-ui/scripts/check.mjs"`
5. Inform the user what changed and how to restore defaults via Settings -> "From ui.json" -> "Restore Defaults".

Full schema definition is available in `schema.json`.

## Schema Example

```json
{
  "version": 1,
  "header": {
    "actions": [
      "schedule",
      "detail",
      "newChat",
      { "id": "daily", "icon": "bolt", "label": "Daily Report", "action": { "type": "send", "text": "Draft today's status report." } }
    ]
  },
  "composer": {
    "quickActions": [
      { "label": "Summarize", "action": { "type": "send", "text": "Summarize above conversation with 3 bullet points." } },
      { "label": "Compact", "action": { "type": "command", "name": "compact" } }
    ]
  },
  "emptyState": {
    "suggestions": [
      { "title": "Check today's tasks", "subtitle": "Read TODO.md in workspace", "action": { "type": "send", "text": "Review TODO.md and list next actions." } }
    ]
  },
  "drawer": {
    "groups": ["pinned", "folders", "today", "yesterday", "thisWeek", "earlier"],
    "sort": "activity",
    "filter": "all"
  },
  "density": "compact",
  "theme": "dark"
}
```
