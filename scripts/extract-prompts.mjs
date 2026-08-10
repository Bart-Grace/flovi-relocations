#!/usr/bin/env node
// Extracts the human-typed prompts from a Claude Code transcript.
//
// The schema was read, not guessed — though not on the first try. `type: 'user'` records
// hold tool results, not typed input: exactly one of them in a 1809-line transcript had a
// text block. The prompts live in `type: 'last-prompt'` records under `lastPrompt`, and
// each turn re-emits the current one, so the raw stream is mostly duplicates.
//
// Usage: node scripts/extract-prompts.mjs <transcript.jsonl> > docs/prompt-log-raw.md

import { createReadStream } from 'node:fs'
import { createInterface } from 'node:readline'

const file = process.argv[2]
if (!file) {
  console.error('usage: extract-prompts.mjs <transcript.jsonl>')
  process.exit(1)
}

const SKIP = [/^\[Request interrupted/, /^<command-name>/, /^<local-command/]

const rl = createInterface({ input: createReadStream(file), crlfDelay: Infinity })
const prompts = []

for await (const line of rl) {
  let row
  try {
    row = JSON.parse(line)
  } catch {
    continue
  }
  if (row.type !== 'last-prompt') continue

  const text = (row.lastPrompt ?? '').trim()
  if (!text) continue
  if (SKIP.some((re) => re.test(text))) continue
  if (prompts.at(-1) === text) continue // consecutive re-emission of the same prompt

  prompts.push(text)
}

console.log('# Raw prompt log\n')
console.log(`Every prompt typed by hand, in order — ${prompts.length} of them.`)
console.log(`Extracted from the Claude Code transcript with \`scripts/extract-prompts.mjs\`.\n`)
prompts.forEach((text, i) => {
  console.log(`## ${i + 1}\n`)
  console.log('```')
  console.log(text)
  console.log('```\n')
})
