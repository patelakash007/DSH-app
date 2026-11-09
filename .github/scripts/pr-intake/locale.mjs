// If Han characters in title+body account for >= 20% of (Han + Latin) or Han >= 12, reply in zh.
// Strip template comments, code blocks, and URLs first to avoid skewing character counts.
export function detectReplyLocale(title, body) {
  const text = `${title || ''}\n${body || ''}`
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`[^`]+`/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
  const cjk = (text.match(/\p{Script=Han}/gu) || []).length
  const latin = (text.match(/[A-Za-z]/g) || []).length
  if (cjk === 0) return 'en'
  if (latin === 0) return 'zh'
  return (cjk / (cjk + latin) >= 0.2 || cjk >= 12) ? 'zh' : 'en'
}
