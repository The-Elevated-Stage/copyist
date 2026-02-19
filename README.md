# Copyist

Creates self-contained task instruction files from implementation plans. The Copyist bridges planning and execution: it transforms plan sections into structured documents that Musician sessions follow autonomously.

## What It Does

- Reads implementation plans and decomposes them into task instruction files
- Applies sequential or parallel task templates with strict section ordering
- Ensures every instruction file is fully self-contained (no external references)
- Validates SQL table names, state transitions, file paths, and session ID patterns
- Produces files ready for immediate Musician consumption

## Structure

```
copyist/
  SKILL.md              # Skill definition (entry point)
  docs/archive/         # Migration review and historical notes
  examples/             # Sequential and parallel task instruction examples
  references/           # Templates, anti-patterns, schema details, launch prompts
  scripts/              # Instruction file validation
```

## Usage

Invoked by the Conductor (or directly) when task instructions need to be generated from a plan. Output goes to `docs/tasks/`.

## Origin

Design docs: [kyle-skills/orchestration](https://github.com/kyle-skills/orchestration) `docs/designs/sequential-task-design.md`, `parallel-task-design.md`
