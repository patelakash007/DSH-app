// dsh-go-example-quick: two capsules above the composer and two items in a
// reply's long-press menu.
//

//              English text lands in the composer (≤ 60 s); without a model, the clipboard
//              wrapped in a translation request goes in instead

//
// `wants: ["clipboard", "message"]` in the manifest is what lets taps carry the
// clipboard (composer capsules) and the reply text (message menu); the app asks
// the person once before the first tap.
import { copyMarkdown, saveNote, TRANSLATE_SYSTEM, translateWithModel } from './actions.js'
import { complete, defaultModel } from './model.js'

export const name = 'dsh-go-example-quick'

export function apply(ctx) {
  const cwdOf = (sessionId) => {
    try {
      return ctx.get('sessions')?.get?.(sessionId)?.header?.cwd
    } catch {
      return undefined
    }
  }

  ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.on('translate', (scope, event) => {
      const route = defaultModel(ctx)
      const model = route && { complete: (text, signal) => complete(route, TRANSLATE_SYSTEM, text, signal) }
      return translateWithModel(scope, event?.locale, model)
    })
    ctx.dshGo.on('copy-md', (scope, event) => copyMarkdown(scope, event?.locale))
    ctx.dshGo.on('save-note', (scope, event) => saveNote(scope, { cwd: cwdOf(scope.sessionId), locale: event?.locale }))
  })
}
