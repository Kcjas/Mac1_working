---
description: Load all context and resume from last session
---

## Goal
Load full project context before touching anything.

## Steps
1. Read `tasks/lessons.md` — apply every lesson, no exceptions
2. Read `tasks/todo.md` — understand current plan and progress
3. Read `tasks/memory.md` — load last session snapshot
4. Summarise to the user:
   - What was completed last session
   - What's currently in progress
   - What's blocked
   - What the next step is
5. Ask: "Ready to continue with [next step], or is there something else?"

## Rules
- Never start working before completing all 3 reads
- If any file doesn't exist, say so and ask user how to proceed
- Apply all lessons before doing anything
