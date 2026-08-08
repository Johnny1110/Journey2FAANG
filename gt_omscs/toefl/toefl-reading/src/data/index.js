// Auto-discovery: dropping a new weekXX.json in this folder is all that is
// needed to make it appear in the app. No registration step.
const modules = import.meta.glob('./week*.json', { eager: true })

export const weeks = Object.values(modules)
  .map((m) => m.default ?? m)
  .sort((a, b) => a.week - b.week)

export function getWeek(id) {
  return weeks.find((w) => w.id === id) ?? null
}

/**
 * Flattens a week into an ordered list of scorable items so the exam and the
 * review screen never have to walk the nested part/block structure themselves.
 */
export function flattenItems(week) {
  const items = []
  for (const part of week.parts) {
    for (const block of part.blocks) {
      if (part.type === 'cloze') {
        for (const blank of block.blanks) {
          items.push({
            id: blank.id,
            kind: 'cloze',
            partId: part.id,
            partTitle: part.title,
            blockTitle: block.title,
            answer: blank.answer,
            prefix: blank.prefix,
            explanation: blank.explanation,
          })
        }
      } else {
        for (const q of block.questions) {
          items.push({
            id: q.id,
            kind: 'choice',
            partId: part.id,
            partTitle: part.title,
            blockTitle: block.title,
            prompt: q.prompt,
            options: q.options,
            answer: q.answer,
            explanation: q.explanation,
          })
        }
      }
    }
  }
  return items.sort((a, b) => a.id - b.id)
}

export function isCorrect(item, response) {
  if (response == null || response === '') return false
  if (item.kind === 'cloze') {
    return normalize(response) === normalize(item.answer)
  }
  return response === item.answer
}

function normalize(s) {
  return String(s).trim().toLowerCase().replace(/[^a-z]/g, '')
}

/**
 * Band estimate. TOEFL does not publish a raw-to-band table for the 2026
 * format, so this is a working heuristic for tracking progress, not an
 * official conversion.
 */
export function estimateBand(ratio) {
  if (ratio >= 0.95) return '6.0'
  if (ratio >= 0.86) return '5.5'
  if (ratio >= 0.75) return '5.0'
  if (ratio >= 0.64) return '4.5'
  if (ratio >= 0.52) return '4.0'
  if (ratio >= 0.4) return '3.5'
  return '3.0 以下'
}

export const LETTERS = ['A', 'B', 'C', 'D']
