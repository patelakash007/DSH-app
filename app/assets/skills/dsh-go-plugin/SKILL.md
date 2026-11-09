---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-plugin
description: Author local plugins for the DSH native mobile app. Renders native components including input capsules, message action menus, status strips, native modal panels, and tool result cards with optional audio playback and subtitles. Validate with the built-in checker and install onto the host engine.
whenToUse: The user wants to add custom logic, buttons, or views to the DSH native Android app. For fixed buttons, layout adjustments, or themes without logic, use the dsh-go-ui skill (ui.json). For Cordis web plugins on the web UI, use the official cordis-plugin-development skill.
---

# Writing a Native DSH Plugin

A plugin is an npm package directory located on the host engine: the `dshGo` manifest in `package.json` declares UI elements that appear in the app, while `lib/index.js` handles interactions and streams dynamic data. The app renders native Flutter widgets from declarative JSON views without executing foreign untrusted code.

## UI Scope & Division of Responsibilities

This skill targets the **native DSH Android application**. In creation mode, `cordis-plugin-development` targets the web interface. Do not confuse the two targets:

| Target | Skill to Use | Directory / Installation |
|---|---|---|
| Native App: capsules, context menus, status strips, native panels, tool cards | `dsh-go-plugin` | `$DSH_HOME/dsh-go/plugins/<name>/`, `dsh plugin --profile web add <dir>` |
| Native App Theme / Fixed Layout | `dsh-go-ui` (`ui.json`) | `$DSH_HOME/dsh-go/ui.json` |
| Web UI / Desktop Plugins / Cordis | `cordis-plugin-development` | Workspace package + `plugin_manager` -> `install_bundle` |

## Slot Selection Guide

| Need | Implementation |
|---|---|
| Static button, header toggle, theme override | Use `dsh-go-ui` to edit `ui.json` |
| Button reading clipboard, composer text, or selected message | Use `composer.actions` / `message.actions` + `on(id)` |
| Persistent numeric status strip | Use `composer.strip` + `strip(id)` |
| Multi-tab info page or settings sheet | Use `panels` + `panel(id)` |
| Specialized action in "+" composer menu | Use `composer.tools` |
| Chat-wide operation (export, archive) | Use `session.actions` |
| Step / turn status badge | Use `turn.note` + `turnNote(id)` |
| Custom card for tool execution output | Return `output.presentationMeta = { "dsh-go/view": view }` |
| Text-to-speech audio with synchronized subtitles | Use `capabilities: ["audio", "voice", "micro", "overlay"]` |

## Development Steps

1. **Create Directory** (stored in `$DSH_HOME/dsh-go/plugins/` to survive resets):
   ```sh
   P="${DSH_HOME:-$HOME/.dsh}/dsh-go/plugins/local-quote"
   mkdir -p "$(dirname "$P")" && cp -r "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/template" "$P"
   ```
2. **Naming**: Set matching `name` values in `package.json`, `cordis.patch.yml`, and `lib/index.js` starting with `local-` (lowercase letters, digits, and hyphens).
3. **Declare Manifest** (`package.json` -> `dshGo`). Request only necessary permissions in `wants`.
4. **Implement Handlers** (`lib/index.js`): Wrap within `ctx.inject(['dshGo'], (ctx) => { ... })`.
5. **Validate**:
   ```sh
   node "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/kit/bin/check.mjs" "$P" --load
   ```
   `--load` evaluates handlers in an isolated sandbox.
6. **Install**:
   ```sh
   dsh plugin --profile web add "$P"
   ```
7. **Reloading**: Manifest changes reload automatically; code changes in `lib/` take effect when restarting the engine from Settings -> Engine.

## Manifest Schema (`package.json` -> `dshGo`)

```json
{
  "v": 1,
  "title": { "zh": "Quote", "en": "Quote" },
  "icon": "bolt",
  "wants": ["clipboard"],
  "contributes": {
    "composer.actions": [
      { "id": "summarize", "label": "Summarize", "effect": { "type": "insert", "text": "Summarize conversation with 3 bullet points." } },
      { "id": "paste-quote", "label": { "en": "Quote clip" }, "icon": "document" }
    ],
    "message.actions": [{ "id": "save", "label": "Save to notes", "icon": "note" }],
    "composer.strip":   [{ "id": "today", "icon": "chart", "panel": "stats" }],
    "panels":           [{ "id": "stats", "title": "Stats", "icon": "chart", "placement": ["session.tab", "features"] }]
  }
}
```

| Slot | Per Plugin | Max Text | Fields | Tap Behavior |
|---|---|---|---|---|
| `composer.actions` | 2 | `label` <= 10 | `id`, `label`, `icon?`, `effect?` | `effect` runs directly in app; otherwise invokes `on(id)` |
| `message.actions` | 2 | `label` <= 12 | Same as above | Same as above |
| `composer.strip` | 1 | `text` <= 24 | `id`, `icon?`, `text?`, `panel?` | `panel` opens target panel; otherwise invokes `on(id)` |
| `panels` | 4 | `title` <= 16 | `id`, `title`, `icon?`, `placement?`, `view?` | Taps dispatch to registered `actions` |
| `composer.tools` | 2 | `label` <= 8 | `id`, `label`, `icon?`, `effect?`, `panel?` | Direct effect/panel or invokes `on(id)` |
| `session.actions` | 2 | `label` <= 12 | `id`, `label`, `icon?`, `effect?` | Dispatches action |
| `turn.note` | 1 | `text` <= 16 | `id` | Non-interactive status; emits `{ turnSeq: { text, tone? } }` |

## Handlers (`ctx.dshGo`)

```js
export const name = 'local-quote'
export function apply(ctx) {
  ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.on('paste-quote', (scope, event) => scope.clipboard ? { insert: `> ${scope.clipboard}` } : { toast: 'Clipboard is empty' })

    ctx.dshGo.strip('today', (scope, emit, caps) => {
      const tick = () => emit({ text: `Today ${count()}` })
      tick()
      const timer = setInterval(tick, 60_000)
      return () => clearInterval(timer)
    })

    ctx.dshGo.panel('stats', {
      view: (scope, caps) => ({ type: 'stack', children: [
        { type: 'metric', label: 'Today', value: { $: 'data.today' } },
        { type: 'actions', items: [{ label: 'Reset', action: 'reset' }] },
      ] }),
      data: (scope, emit, caps) => { emit({ today: count() }); return () => {} },
      actions: { reset: (scope, event) => ({ toast: 'Reset complete', patch: { today: 0 } }) },
    })
  })
}
```

### Supported Effects:
- `{ insert: '...' }`: Inserts text into the composer (never auto-sent).
- `{ toast: '...' }`: Transient notification message.
- `{ copy: '...' }`: Copies text to clipboard.
- `{ link: 'https://...' }`: Prompts user and opens verified HTTPS URL in external browser.
- `{ open: 'panel:stats' }`: Opens panel or app screen.
- `{ refresh: true }` / `{ patch: {...} }`: Re-fetches view or merges state.
