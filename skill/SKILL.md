---
name: copyist
description: This skill should be used when a subagent needs to "write task instructions", "create task instruction files", "generate execution instructions from an implementation plan", or "create sequential or parallel task instructions". It provides templates, coordination patterns, and validation rules for producing self-contained task instruction files that musician sessions follow autonomously.
version: 2.0
---

<sections>
- mandatory-rules
- purpose
- workflow
- writing-rules
- validation
- rag-fallback
- anti-patterns
</sections>

# Copyist

<section id="mandatory-rules">
<mandatory>
- Must read the selected template FIRST, then match every section exactly — the template is the mandatory skeleton
- Every section heading in the template must appear in the generated instruction file, in order
- If a section does not apply, keep the heading and write "N/A — [reason]" — never skip, merge, or reorder sections
- All SQL must use `orchestration_tasks` and `orchestration_messages` — never old table names
- All INSERTs into `orchestration_messages` must include `message_type` — no NULL values
- Every state transition must include `last_heartbeat = datetime('now')`
- Every instruction file must be self-contained — never write "see implementation plan section X"
- All file paths must be explicit and complete — no ambiguous locations
- All scratch/ephemeral files must use `temp/` (project root) — never `/tmp/` directly
- All session ID references must use `$CLAUDE_SESSION_ID` — never `[session-id]`
- Generated task instructions must be Tier 3 `<task-instruction>` documents — all text inside tags
</mandatory>
</section>

<section id="purpose">
<core>
## Purpose

Convert implementation plan phase sections into self-contained task instruction files. Each instruction file contains everything a musician session needs to complete its work autonomously — no external document references required. The conductor launches a subagent with this skill to create instruction files for one phase at a time.
</core>

<context>
The copyist receives a line range pointing to a self-contained phase section in an Arranger-produced implementation plan. It reads only that section, decomposes it into tasks, and produces one `<task-instruction>` file per task.
</context>
</section>

<section id="workflow">
<core>
## Workflow

### 1. Receive Input from Conductor

The conductor prompt provides:
- **Task type**: sequential or parallel
- **Phase**: which phase of the implementation plan
- **Line range**: `{LINE_START}-{LINE_END}` — the self-contained phase section boundaries
- **Plan path**: path to the implementation plan
- **Task IDs**: assigned task identifiers (e.g., task-03, task-04)
- **Overrides & Learnings**: conductor corrections and accumulated knowledge
- **Output path**: where to write instruction files

<reference path="references/launch-prompt-template.md" load="recommended">
Standard prompt format and field documentation for the conductor's launch prompt.
</reference>

### 2. Read Assigned Phase Section

Read only the assigned lines from the implementation plan:

```
Read {PLAN_PATH}, offset={LINE_START}, limit={LINE_END - LINE_START + 1}
```

<mandatory>Read only the assigned phase section by line range. Do not read the full plan.</mandatory>

The phase section is self-contained — it includes objective, prerequisites, implementation detail, integration points, and expected outcomes.

<context>
#### Plan Structure

Arranger-produced plans wrap each phase in sentinel markers:

```
<!-- phase:N -->
## Phase N: [Title]
[phase content]
<!-- /phase:N -->
```

The Conductor extracts line ranges from the plan index at the top of the file (`<!-- plan-index:start -->` block containing `<!-- phase:N lines:NN-NN title:"..." -->` entries) and passes them in the launch prompt. You should receive a clean phase section.

**Expected phase components** (in order, all present):
- **Objective** — what this phase accomplishes
- **Prerequisites** — outputs from prior phases, file paths, preconditions
- **Implementation detail** — specific enough to write task instructions without inference
- **Integration points** — how this phase connects to other phases' work
- **Frontend guidelines** — when applicable, inlined directly (not a separate reference)
- **Expected outcomes** — what success looks like
- **Testing recommendations** — testing considerations from planning

**Not part of the phase section:** Conductor-review checkpoints (`<!-- conductor-review:N -->`) follow each phase but are the Conductor's concern, not the Copyist's. If your line range includes review content, ignore it.

**Verification:** The first non-blank line should match `<!-- phase:N -->` and the last should match `<!-- /phase:N -->`. If not, the line range may be off — report to the Conductor rather than guessing.
</context>

### 3. Select Template

Read the appropriate template from this skill's references:

<reference path="references/sequential-task-template.md" load="required">
Template for sequential (non-hook) task instructions.
</reference>

<reference path="references/parallel-task-template.md" load="required">
Template for parallel (hook-coordinated) task instructions.
</reference>

<guidance>
For deep context on design rationale, pattern selection criteria, and comprehensive examples beyond what the templates provide, consult the design specifications:
- **Sequential design**: `docs/reference/designs/sequential-task-design.md`
- **Parallel design**: `docs/reference/designs/parallel-task-design.md`
</guidance>

### 4. Read Schema Reference

<reference path="references/schema-and-coordination.md" load="required">
Database DDL, state machine, all SQL patterns, state ownership rules.
</reference>

### 5. Decompose Phase into Tasks

For each task ID provided by the conductor, create one instruction file using the selected template as the mandatory structure.

<mandatory>The launch prompt's Overrides & Learnings take precedence over the implementation plan. When they conflict, the prompt wins.</mandatory>

### 6. Write Instruction Files

Apply the core writing rules (see section below) to each instruction file.

### 7. Self-Review + Validation

After writing each instruction file, check against the validation checklist. Then run:

```bash
bash ~/.claude/skills/copyist/scripts/validate-instruction.sh <file>
```

Fix any issues before returning to conductor.

### 8. Final Context Estimate

After writing each instruction file, calculate the total context load for the musician session:
- Cumulative file-read estimate from all steps (the 140k work estimate)
- PLUS the size of the generated instruction file itself (it loads into the musician's context)

**Total session cap: 170k tokens.** The 170k total includes the 140k file-read budget from the work steps plus the instruction file itself loaded into the musician's context.

<guidance>
If any task's combined estimate exceeds 170k, report to the conductor before splitting. Include:
- Total instruction files written successfully
- Number of tasks exceeding the 170k cap
- For each over-cap task: the task ID, estimated total, and which steps are the largest context consumers
- Proposed split strategy (where to divide the work)

This is a pass/fail/advice check — the conductor confirms the split approach or provides alternative guidance.
</guidance>
</core>
</section>

<section id="writing-rules">
<core>
## Core Writing Rules

### Context Estimates (Per Step)

Before writing each task instruction, review every file the task will read or modify. For each file, determine its size and estimate the context it will consume when read. Include these estimates in each Work Execution step.

<guidance>
**How to estimate:**
- For full file reads: use actual file size (check with `wc -l` or file size)
- For section reads: assume the Read tool's default max (2000 lines) unless the step provides explicit line offset/limit guidance — prefer providing line guidance to control extraction size
- Over-estimate rather than under-estimate

**Format per step:**
```
### Step N: [Action]
**Context estimate:** ~Xk tokens
- `path/to/file.md` — ~Y lines (full read)
- `path/to/large-file.dart` — ~Z lines (lines 50-150, widget section)
**Running total:** ~Xk / 140k
```
</guidance>

### Prompt Precedence

<mandatory>
The conductor's launch prompt takes precedence over the implementation plan. The prompt may include overrides, scope adjustments, danger file decisions, and learnings from prior phases that supersede what the plan says. When the prompt and plan conflict, follow the prompt.
</mandatory>

### Self-Containment

- Copy all relevant plan content into the instruction — musician sessions do not load the implementation plan
- Include complete SQL patterns, not references to "the standard pattern"
- Embed verification commands with expected output

### Coordination Sections

- Sequential tasks: simple state updates (working → complete), manual message checks
- Parallel tasks: hook setup, background subagent, review checkpoints, error recovery — all mandatory

### Testing Requirements

- Every task instruction must specify what tests to run and expected outcomes
- Include test file paths and example test structures where applicable
- Manual verification checklist required for all tasks

### Proposals

<guidance>
Include proposal requirements when the task involves:
- New patterns or conventions (RAG proposal)
- Schema changes (database proposal)
- API changes (API proposal)
- Convention changes (spec proposal)

Mark proposals as REQUIRED in the deliverables section — not optional.
</guidance>

### Subagent Delegation Steps

<guidance>
When a task step involves delegating work to a subagent (common in musician tasks), structure the delegation prompt with these sections: **Task** (what to do), **Context** (relevant background), **Requirements** (acceptance criteria), **Constraints** (boundaries), **Deliverables** (expected outputs). Extract only the specific step being delegated — do NOT pass the full task instruction to the subagent.
</guidance>

### Message Field Standards

Musician messages to the conductor follow standardized formats. When writing message templates in task instructions, include the required fields for each message type:

- **Review requests:** Context Usage (%), Self-Correction (YES/NO), Deviations (count + severity), Agents Remaining (count (description)), Proposal (path), Summary, Files Modified (count), Tests (status), Smoothness (0-9), Reason (why review needed)
- **Error reports:** Retry count (N/5), Step (which failed), Error (specific message), Context (relevant state), Proposed fix
- **Completion reports:** Summary, Report path, Commit SHA, Verification status

### Smoothness Scale

Review request messages include a smoothness score (0-9). Include this scale in task instructions so musicians self-assess accurately:

| Score | Meaning |
|-------|---------|
| 0 | Perfect execution, no deviations |
| 1-2 | Minor clarifications, self-resolved |
| 3-4 | Some deviations, documented |
| 5-6 | Significant issues, conductor input needed |
| 7-8 | Major blockers, multiple review cycles |
| 9 | Failed or incomplete, needs redesign |
</core>
</section>

<section id="validation">
<core>
## Validation Checklist

Before returning instruction files to conductor, verify each file:

### Section Completeness (Sequential)

- [ ] Header metadata (in `<metadata>` tag: parallel-safe, dependencies, token-estimate, review-checkpoints)
- [ ] `<section id="mandatory-rules">` with collected `<mandatory>` block
- [ ] Objective (with Critical success criteria)
- [ ] Prerequisites (SQL dependency check + filesystem checks)
- [ ] Bootstrap / Initialization (Claim Task SQL)
- [ ] Work Execution (numbered steps with heartbeats + between-step message checks)
- [ ] RAG Proposal Creation *(if task involves RAG work — otherwise N/A with reason)*
- [ ] Verification Checklist (Verify/Expected/If-failed format for every check)
- [ ] Testing Requirements (specific tests, not "run tests")
- [ ] Completion (Commit Changes, Update Database, Completion Report)
- [ ] Deliverables (Code, Reports, Proposals — each marked required or N/A)
- [ ] Error Recovery (error reporting SQL + conductor message wait)
- [ ] Reference (plan path + design path with section pointers)

### Section Completeness (Parallel — all of the above, PLUS)

- [ ] Initialization includes Database claim (activates hook automatically), Background Subagent launch
- [ ] Review Checkpoint (commit, review request message, blocking wait subagent)
- [ ] Post-Review Execution (steps after conductor approval)
- [ ] Success Criteria (task-specific + standard completion criteria)
- [ ] Review request messages include all 10 required fields (Context Usage, Smoothness, Deviations, Reason, etc.)

### Content Quality

- [ ] All SQL uses `orchestration_tasks` and `orchestration_messages`
- [ ] All INSERTs include `message_type` column with valid value
- [ ] Every state transition includes `last_heartbeat = datetime('now')`
- [ ] All session ID references use `$CLAUDE_SESSION_ID`
- [ ] No references to external documents ("see plan section X")
- [ ] All file paths are explicit and complete
- [ ] Completion report path specified
- [ ] Temporary file paths use `temp/` not `/tmp/`
- [ ] Tier 3 format: all text inside authority tags, no naked markdown
- [ ] `<task-instruction>` wrapper present with id and type attributes
- [ ] `<sections>` index present listing all section IDs
- [ ] `<section id="mandatory-rules">` is first section after metadata
</core>
</section>

<section id="rag-fallback">
<guidance>
## RAG Fallback Queries

When the conductor has not pre-fetched needed information, query the local RAG server:

| Need | Query |
|------|-------|
| SQL coordination patterns | `SQL patterns coordination database queries templates conductor musician` |
| State machine details | `state machine database schema all states CHECK constraints` |
| Error handling workflow | `musician error reporting structured template retry logic terminal error` |
| Review checkpoint process | `musician coordination checkpoints review request blocking subagent approval` |
| Hook configuration | `custom hook setup stop hook preset configuration exit criteria` |
| Danger files protocol | `danger files protocol shared resources barrel exports coordination` |
| Pattern selection guide | Read `docs/reference/designs/sequential-task-design.md` (Part 1: Pattern Selection Guide) |
| Complete worked example | Read `docs/reference/designs/sequential-task-design.md` (Part 5) or `parallel-task-design.md` examples |

**Score interpretation**: < 0.3 = good match, 0.3-0.5 = moderate, > 0.5 = refine query.
</guidance>
</section>

<section id="anti-patterns">
<core>
## Anti-Patterns

<reference path="references/anti-patterns.md" load="recommended">
Complete anti-pattern list with wrong/correct examples.
</reference>

Critical ones:

- **"See plan" references**: Never reference external documents. Copy content in.
- **Missing heartbeats**: Every state transition needs `last_heartbeat = datetime('now')`.
- **Old table names**: Never use `migration_tasks`, `coordination_status`, `task_messages`, or `status` column.
- **Missing `message_type`**: Every INSERT into `orchestration_messages` must specify `message_type`.
- **Ambiguous file paths**: Every deliverable needs an exact path.
- **Missing error recovery**: Parallel tasks must have the full error → fix_proposed → retry cycle.
- **Skipping review checkpoints**: Parallel tasks must pause for conductor review at specified points.
- **Naked text in Tier 3**: All text in `<task-instruction>` output must be inside authority tags.
- **`[STRICT]`/`[FLEXIBLE]` markers**: Use `<mandatory>`/`<core>`/`<guidance>` tags instead.
- **Reading full plan**: Read only the assigned phase section by line range.
</core>
</section>
