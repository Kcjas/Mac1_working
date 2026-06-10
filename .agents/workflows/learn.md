---
description: Log a lesson after a correction
---

## Goal
Log a lesson after a correction. Appends to `tasks/lessons.md` in format: `[date] | what went wrong | rule to prevent it`

## Steps
1. Read `tasks/lessons.md` — load existing entries for context
2. Ask the user: "What went wrong and what's the rule to prevent it?"
3. Append a new line in this exact format:
   `[YYYY-MM-DD] | what went wrong | rule to prevent it`
4. Confirm the entry was written successfully

## Rules
- Append only — never overwrite or reformat existing entries
- If `tasks/lessons.md` doesn't exist, create it first
- Keep each lesson to one line, concise
