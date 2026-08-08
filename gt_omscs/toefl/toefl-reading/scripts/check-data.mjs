#!/usr/bin/env node
// Validates every src/data/weekXX.json against the format rules in README.md.
// Run after adding a new week: npm run check
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const dataDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'data')
const files = readdirSync(dataDir)
  .filter((f) => /^week\d+\.json$/.test(f))
  .sort()

if (!files.length) {
  console.log('No week data files found in src/data/.')
  process.exit(0)
}

let failures = 0

for (const file of files) {
  const errors = []
  const bad = (msg) => errors.push(msg)

  let week
  try {
    week = JSON.parse(readFileSync(join(dataDir, file), 'utf8'))
  } catch (e) {
    console.log(`✗ ${file}: invalid JSON — ${e.message}`)
    failures++
    continue
  }

  for (const key of ['id', 'week', 'title', 'date', 'topics', 'timeLimitSec', 'parts']) {
    if (week[key] == null) bad(`missing top-level key "${key}"`)
  }
  if (week.id && `${week.id}.json` !== file) bad(`id "${week.id}" does not match filename`)

  const ids = []

  for (const part of week.parts ?? []) {
    if (!['cloze', 'choice'].includes(part.type)) bad(`part "${part.id}": unknown type "${part.type}"`)

    for (const block of part.blocks ?? []) {
      if (part.type === 'cloze') {
        const markers = [...block.template.matchAll(/\{\{(\d+)\}\}/g)].map((m) => Number(m[1]))
        const blanks = (block.blanks ?? []).map((b) => b.id)

        for (const id of markers)
          if (!blanks.includes(id)) bad(`${block.title}: marker {{${id}}} has no matching blank`)
        for (const id of blanks)
          if (!markers.includes(id)) bad(`${block.title}: blank ${id} has no {{${id}}} in template`)

        for (const b of block.blanks ?? []) {
          ids.push(b.id)
          if (!b.answer.startsWith(b.prefix))
            bad(`#${b.id}: answer "${b.answer}" does not start with prefix "${b.prefix}"`)
          if (b.prefix.length + b.missing !== b.answer.length)
            bad(
              `#${b.id}: "${b.answer}" is ${b.answer.length} letters but prefix(${b.prefix.length}) + missing(${b.missing}) = ${b.prefix.length + b.missing}`,
            )
          if (!b.explanation) bad(`#${b.id}: missing explanation`)
        }
      } else {
        if (!Array.isArray(block.body) || !block.body.length) bad(`${block.title}: empty body`)
        for (const q of block.questions ?? []) {
          ids.push(q.id)
          if (q.options?.length !== 4) bad(`Q${q.id}: has ${q.options?.length} options, expected 4`)
          if (!['A', 'B', 'C', 'D'].includes(q.answer)) bad(`Q${q.id}: bad answer "${q.answer}"`)
          if (!q.explanation) bad(`Q${q.id}: missing explanation`)
        }
      }
    }
  }

  if (new Set(ids).size !== ids.length) bad('duplicate item ids')
  ;[...ids]
    .sort((a, b) => a - b)
    .forEach((id, i) => {
      if (id !== i + 1) bad(`item ids must run 1..N with no gaps — expected ${i + 1}, got ${id}`)
    })

  if (errors.length) {
    failures++
    console.log(`✗ ${file} (${ids.length} items)`)
    for (const e of errors) console.log(`    ${e}`)
  } else {
    console.log(`✓ ${file} — ${ids.length} items`)
  }
}

process.exit(failures ? 1 : 0)
