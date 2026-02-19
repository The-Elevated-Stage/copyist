<skill name="copyist-launch-prompt" version="2.0">

<metadata>
type: reference
parent-skill: copyist
tier: 3
</metadata>

<sections>
- template
- field-reference
- precedence-rules
- notes
</sections>

<section id="template">
<core>
## Launch Prompt Template

<template follow="format">
```
Load the copyist skill, then create task instruction files for this phase.

## Phase Info
**Phase:** {N} — {NAME}
**Task type:** {TYPE} (sequential/parallel)
**Tasks to create:** {TASK_LIST}
**Implementation plan:** {PLAN_PATH}
**Phase section:** lines {LINE_START}-{LINE_END}
**Output directory:** docs/tasks/

## Overrides & Learnings
{CONDUCTOR_NOTES}

## Instructions
1. Read lines {LINE_START}-{LINE_END} of the plan at `{PLAN_PATH}` — this is your assigned phase section
2. Invoke the `copyist` skill
3. Read the appropriate template (sequential or parallel) — following templates is MANDATORY
4. Read the schema reference for SQL patterns
5. Decompose the phase into tasks listed above
6. Apply any Overrides & Learnings — these take precedence over the plan
7. Write instruction files to `docs/tasks/`
8. Validate each file and fix errors until all pass

Report validation results for each file when done.
```
</template>
</core>

<context>
The conductor constructs this prompt by filling in the template fields. The copyist should not modify or question the Phase Info fields — they are authoritative. The `## Instructions` section is fixed boilerplate. The conductor does not modify it.
</context>

<guidance>
The copyist may split tasks further if context estimates exceed the 170k cap. When splitting, report back to the conductor for approval before writing the additional instruction files.
</guidance>
</section>

<section id="field-reference">
<core>
## Field Reference

### Phase Info (Required)

| Field | Description | Example |
|-------|-------------|---------|
| `{N}` | Phase number from the implementation plan | `2` |
| `{NAME}` | Phase name from the implementation plan | `Extract Testing Documentation` |
| `{TYPE}` | Task coordination pattern — determines which template to use | `parallel` or `sequential` |
| `{TASK_LIST}` | Specific task IDs to create instruction files for | `task-03, task-04, task-05, task-06` |
| `{PLAN_PATH}` | Absolute or project-relative path to the implementation plan | `docs/plans/implementation/2026-02-17-feature-implementation.md` |
| `{LINE_START}` | First line of the phase section (from plan index) | `145` |
| `{LINE_END}` | Last line of the phase section (from plan index) | `298` |

### Overrides & Learnings (Required — may be empty)
</core>

<context>
This section is the conductor's mechanism for passing corrections, scope adjustments, and accumulated knowledge to the copyist. Contents of this section take precedence over the implementation plan.
</context>

<core>
Common override types:

| Type | Description | Example |
|------|-------------|---------|
| **Hard-coded corrections** | Fixes for known errors in the plan | "Plan says `docs/guidelines/` — renamed to `docs/knowledge-base/` in phase 1" |
| **Scope adjustments** | Tasks added, removed, or resized by conductor | "Task-05 scope reduced: skip API docs extraction, handle in phase 3" |
| **Danger file decisions** | Shared files that need coordination between parallel tasks | "Both task-03 and task-04 modify `docs/README.md` — task-04 owns it, task-03 must not touch it" |
| **Learnings from prior phases** | Patterns discovered during earlier execution | "RAG proposals should use one-proposal-per-file format (discovered in phase 1)" |
| **Context budget guidance** | Conductor knows certain files are large | "TESTING_GUIDE.md is 1200 lines — instruct musician to read in sections" |
| **Implementation adjustments** | Changes to implementation approach | "Plan specifies 5 API endpoints, scope reduced to 3 for this phase" |
</core>

<guidance>
If the Overrides & Learnings section is empty, the conductor will write "None — follow the implementation plan as written." An empty section does not mean the field can be omitted.
</guidance>
</section>

<section id="precedence-rules">
<mandatory>
## Precedence Rules

When writing task instructions, the copyist draws from two sources. They are applied in this priority order:

1. **Launch prompt (Overrides & Learnings)** — highest priority. These reflect the conductor's real-time decisions and accumulated session knowledge.
2. **Implementation plan phase section** — baseline. Provides the detailed task descriptions, file lists, and acceptance criteria.

**When they conflict, the prompt wins.** Examples:
- Plan says to create 20 RAG files, prompt says "scope reduced to 12" → create 12
- Plan says task-03 modifies `docs/README.md`, prompt says "task-04 owns README.md" → task-03 must not touch it
- Plan uses an old directory name, prompt corrects it → use the corrected name

**When the prompt is silent**, follow the plan. The prompt only overrides what it explicitly addresses — everything else in the plan remains in effect.
</mandatory>
</section>

<section id="notes">
<context>
## Notes

- The copyist is **always** a subagent launched by a conductor session. It never runs standalone.
- The conductor reads the plan's verification index to get line ranges for each phase section, then passes those line ranges to the copyist in the launch prompt.
- The phase section is self-contained — the copyist should rarely need to reference the plan's overview section. Doing so defeats the context-constraining purpose of self-containment.
- Output directory defaults to `docs/tasks/` but the conductor may override this in the prompt.
</context>
</section>

</skill>
