// Effect constructors for handler results (native-plugins-protocol.md §5).
// Handlers may also return the shorthand ({ insert: '…' }); these exist for
// readability and types. The app runs effects only within 3 s of the tap.

/** Put text into the composer at the cursor (1–2000 characters). Never sends. */
export const insert = (text) => ({ type: 'insert', text })
/** Run a slash command in the current chat: command('compact'), command('goal', 'ship it'). */
export const command = (name, args) => (args === undefined ? { type: 'command', name } : { type: 'command', name, args })
/** Open an app page id (feature catalog) or `panel:<id>` of this plugin. */
export const open = (page) => ({ type: 'open', page })
/** Open one of this plugin's panels. */
export const openPanel = (id) => ({ type: 'open', page: `panel:${id}` })
/** Open an https URL in the browser after the person confirms. */
export const link = (url) => ({ type: 'link', url })
/** One-line notice (≤ 40 characters). */
export const toast = (text) => ({ type: 'toast', text })
/** Copy text to the clipboard (1–8000 characters). */
export const copy = (text) => ({ type: 'copy', text })
/** Re-fetch a panel's view (default: the panel the tap came from). */
export const refresh = (id) => (id === undefined ? { type: 'refresh' } : { type: 'refresh', id })
/** Merge into a panel's data now (JSON Merge Patch, ≤ 16 KiB). */
export const patch = (data, id) => (id === undefined ? { type: 'patch', data } : { type: 'patch', data, id })

/** System file chooser after a direct tap; callback receives event.value { status, files }. */
export const pickFile = (action, { maxFiles = 1 } = {}) => ({ type: 'pickFile', action, maxFiles })
/** System gallery chooser; the same read-only snapshot and callback lifetime as pickFile. */
export const pickImage = (action, { maxFiles = 1 } = {}) => ({ type: 'pickImage', action, maxFiles })

export const deferred = (work, { label, timeoutMs } = {}) => ({
  pending: label === undefined && timeoutMs === undefined ? true : { ...(label === undefined ? {} : { label }), ...(timeoutMs === undefined ? {} : { timeoutMs }) },
  result: work,
})
