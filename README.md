# Copyist: Score Parts for Autonomous Sessions

In a traditional orchestra, the copyist sits between composer and performer. The full score holds every instrument's line — but no violinist plays from the full score. The copyist extracts each player's part: complete, self-contained, ready to perform without referencing the master document.

The `copyist` skill does the same for implementation plans. It reads a single phase from an Arranger-produced plan and produces self-contained task instruction files — everything a Musician session needs to execute autonomously, with no external references required.

## Copyist vs Raw Handoff

| | Raw plan handoff | Copyist output |
|---|---|---|
| **Self-containment** | References other sections, assumes shared context | Every instruction file stands alone — no "see plan section X" |
| **SQL correctness** | May use stale table names or miss required fields | Enforces `orchestration_tasks`/`orchestration_messages`, mandatory `message_type` |
| **State management** | Heartbeats and transitions often omitted | Every state transition includes `last_heartbeat = datetime('now')` |
| **Context budgeting** | No awareness of session token limits | Per-step estimates with 140k work + instruction size, 170k session cap |
| **Validation** | Manual review | Machine-validated via `validate-instruction.sh` |
| **Format** | Free-form markdown | Tier 3 `<task-instruction>` with mandatory section skeleton |

## Where Copyist Fits

```
Arranger          Conductor          Copyist           Musician
(plan phases) --> (orchestrate) ---> (extract parts) --> (perform)
                      |                                    |
                      └── reviews output <─────────────────┘
```

The Conductor never hands raw plan text to Musicians. It launches a Copyist teammate with a specific phase's line range, receives validated instruction files back, then dispatches Musicians to execute them.

## How It Works

1. **Receive** — Conductor provides: task type (sequential/parallel), phase line range, plan path, task IDs, overrides, and output path.
2. **Read** — Load only the assigned phase section by line range. Never the full plan.
3. **Template** — Select the sequential or parallel task template and match every section exactly.
4. **Decompose** — Transform the phase into one instruction file per task, embedding all context inline.
5. **Budget** — Estimate per-step context consumption. Flag any task exceeding the 170k session cap.
6. **Validate** — Self-review against the checklist, then run `validate-instruction.sh`.
7. **Return** — Deliver instruction files to the Conductor.

## Protocol Guardrails

| Rule | Detail |
|------|--------|
| Template skeleton | Every section heading from the template must appear, in order. Unused sections get "N/A — [reason]" |
| Table names | `orchestration_tasks` and `orchestration_messages` only — never legacy names |
| Message inserts | Every INSERT into `orchestration_messages` must include `message_type` |
| Heartbeats | Every state transition includes `last_heartbeat = datetime('now')` |
| Self-containment | No external references. All plan content copied into the instruction |
| File paths | Explicit and complete — no ambiguous locations |
| Session IDs | `$CLAUDE_SESSION_ID` — never `[session-id]` |
| Temp files | `temp/` (project root) — never `/tmp/` directly |
| Output format | Tier 3 `<task-instruction>` — all text inside authority tags |
| Prompt precedence | Conductor overrides and learnings take precedence over plan content |

## Smoothness Scale

Task instructions include a self-assessment scale that Musicians use in review requests:

| Score | Meaning |
|-------|---------|
| 0 | Perfect execution, no deviations |
| 1-2 | Minor clarifications, self-resolved |
| 3-4 | Some deviations, documented |
| 5-6 | Significant issues, conductor input needed |
| 7-8 | Major blockers, multiple review cycles |
| 9 | Failed or incomplete, needs redesign |

## Validation

Every instruction file is checked before delivery:

```bash
bash skill/scripts/validate-instruction.sh <file>
```

The validator checks section completeness (all required headings present and ordered), SQL correctness (table names, `message_type` presence, heartbeat inclusion), file path validity, Tier 3 format compliance, and `<task-instruction>` wrapper structure.

## Project Structure

```
copyist/
├── skill/
│   ├── SKILL.md                          # Skill definition (entry point)
│   ├── references/
│   │   ├── anti-patterns.md              # Wrong/correct examples
│   │   ├── launch-prompt-template.md     # Conductor launch prompt format
│   │   ├── parallel-task-template.md     # Parallel task skeleton
│   │   ├── schema-and-coordination.md    # Database DDL + SQL patterns
│   │   └── sequential-task-template.md   # Sequential task skeleton
│   ├── examples/
│   │   ├── parallel-task-example.md      # Complete parallel instruction
│   │   └── sequential-task-example.md    # Complete sequential instruction
│   └── scripts/
│       └── validate-instruction.sh       # Instruction file validator
└── docs/
    ├── archive/                          # Historical reviews and migrations
    ├── designs/                          # Skill design specifications
    └── working/                          # Active design work
```

## Usage

Invoked by the Conductor as a teammate when task instructions need to be generated from a plan phase. Can also be invoked directly via `/copyist`.

## Origin

Part of [The Elevated Stage](https://github.com/The-Elevated-Stage) orchestration system. Design docs: `docs/designs/sequential-task-design.md`, `docs/designs/parallel-task-design.md`.
