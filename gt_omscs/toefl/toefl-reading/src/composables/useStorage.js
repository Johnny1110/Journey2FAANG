const RESULTS_KEY = 'toefl-reading:results'
const DRAFT_KEY = 'toefl-reading:draft'

function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Storage full or blocked (private mode) — practice still works, only
    // history is lost, so there is nothing useful to do here.
  }
}

export function loadResults() {
  return read(RESULTS_KEY, [])
}

export function saveResult(result) {
  const all = loadResults()
  all.unshift(result)
  write(RESULTS_KEY, all.slice(0, 100))
}

export function bestFor(weekId) {
  const runs = loadResults().filter((r) => r.weekId === weekId)
  if (!runs.length) return null
  return runs.reduce((best, r) => (r.correct > best.correct ? r : best))
}

export function attemptsFor(weekId) {
  return loadResults().filter((r) => r.weekId === weekId).length
}

export function clearResults() {
  write(RESULTS_KEY, [])
}

export function loadDraft(weekId) {
  const draft = read(DRAFT_KEY, null)
  return draft && draft.weekId === weekId ? draft : null
}

export function saveDraft(draft) {
  write(DRAFT_KEY, draft)
}

export function clearDraft() {
  try {
    localStorage.removeItem(DRAFT_KEY)
  } catch {
    // see write()
  }
}
