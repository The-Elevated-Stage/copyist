<skill name="copyist-anti-patterns" version="2.0">

<metadata>
type: reference
parent-skill: copyist
tier: 3
</metadata>

<sections>
- critical
- structural
- quality
- format
- anti-pattern-guard-clause
- anti-pattern-polling-intervals
</sections>

<section id="critical">
<core>
## Critical Anti-Patterns (Must Avoid)

### 1. External Document References
</core>

<core>
**Wrong:**
```markdown
## Context
See implementation plan section 2.3 for details.
```

**Correct:**
```markdown
## Context
Implementation Plan: [path] (for reference only)

## Implementation Steps
[Complete details copied directly from plan section 2.3]
```
</core>

<context>
Musician sessions do not load the implementation plan. They rely entirely on the task instruction being self-contained.
</context>

<core>
### 2. Old Table Names

**Wrong:**
```sql
UPDATE migration_tasks SET status = 'in_progress' WHERE task_id = 'task-03';
UPDATE coordination_status SET state = 'working' WHERE task_id = 'task-03';
INSERT INTO task_messages (task_id, from_session, message) VALUES (...);
```

**Correct:**
```sql
UPDATE orchestration_tasks
SET state = 'working',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';

INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-03', '$CLAUDE_SESSION_ID', '...', 'instruction');
```
</core>

<context>
The schema uses `orchestration_tasks` and `orchestration_messages`. There is no `status` column — only `state`. There is no `coordination_status` table — it was merged into `orchestration_tasks`.
</context>

<core>
### 3. Missing Heartbeats

**Wrong:**
```sql
UPDATE orchestration_tasks SET state = 'needs_review' WHERE task_id = 'task-03';
```

**Correct:**
```sql
UPDATE orchestration_tasks
SET state = 'needs_review',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</core>

<context>
Every state transition must update `last_heartbeat`. Staleness detection depends on this. Missing heartbeats cause the conductor to think the session has crashed.
</context>

<core>
### 4. Ambiguous File Paths

**Wrong:**
```markdown
## Deliverables
- [ ] Write implementation report
- [ ] Save output somewhere appropriate
```

**Correct:**
```markdown
## Deliverables
- [ ] Implementation report: `docs/implementation/reports/task-03-report.md`
- [ ] RAG files: `docs/knowledge-base/testing/[pattern-name].md`
```
</core>

<context>
Musician sessions follow instructions literally. Ambiguous paths cause files to be created in unexpected locations, making conductor review impossible.
</context>

<core>
### 5. Dual-Table Updates (Obsolete Pattern)

**Wrong:**
```sql
-- Old pattern: update two tables separately
UPDATE coordination_status SET state = 'working' WHERE task_id = 'task-03';
UPDATE migration_tasks SET status = 'in_progress' WHERE task_id = 'task-03';
```

**Correct:**
```sql
-- Single table, single update
UPDATE orchestration_tasks
SET state = 'working',
    started_at = datetime('now'),
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</core>

<context>
The old 3-table schema was merged into 2 tables. There is only one table for task state now.
</context>

<core>
### 6. Missing message_type in INSERTs

**Wrong:**
```sql
INSERT INTO orchestration_messages (task_id, from_session, message)
VALUES ('task-03', '$CLAUDE_SESSION_ID', 'TASK COMPLETE: ...');
```

**Correct:**
```sql
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-03', '$CLAUDE_SESSION_ID', 'TASK COMPLETE: ...', 'completion');
```
</core>

<context>
The `message_type` column has a CHECK constraint with 12 valid values. All INSERTs must specify a type. NULL message_type values violate the orchestration protocol — the conductor uses message_type for routing and filtering.
</context>
</section>

<section id="structural">
<core>
## Structural Anti-Patterns

### 7. Missing Error Recovery (Parallel Tasks)

**Wrong:** No error recovery section in a parallel task instruction.

**Correct:** Include the full error → report → wait for fix_proposed → apply fix → retry cycle. Include the terminal failure case (5th retry → exited state).
</core>

<context>
Parallel tasks run unattended. Without error recovery, a failure stops the task permanently with no way for the conductor to help.
</context>

<core>
### 8. Missing Review Checkpoints (Parallel Tasks)

**Wrong:** Parallel task runs straight through without pausing for conductor review.

**Correct:** Pause at specified checkpoints: commit work, request review, wait for approval/rejection via blocking subagent.
</core>

<context>
Review checkpoints are the conductor's quality control mechanism. Without them, bad work propagates unchecked.
</context>

<core>
### 9. Missing Background Subagent (Parallel Tasks)

**Wrong:** Parallel task has no monitoring subagent for conductor messages.

**Correct:** Launch background subagent at initialization. Check between steps. Relaunch after review checkpoints.
</core>

<context>
The conductor communicates via database messages. Without a monitoring subagent, the musician session misses urgent instructions (stop, change approach, danger file alert).
</context>

<core>
### 10. Starting Work Before Claiming Task (Parallel Tasks)

**Wrong:** Parallel task starts working before claiming the task in the database (writing `session_id`).

**Correct:** The task claim SQL (which writes `session_id` to `orchestration_tasks`) must be the first step of initialization. The stop hook activates automatically once the session's `$CLAUDE_SESSION_ID` is found in the database — no manual setup is needed.
</core>

<context>
The hook prevents the session from exiting before the task reaches a terminal state (complete or exited). Without the claim, the hook has no row to match and the session might exit mid-work.
</context>

<core>
### 11. Code in Conductor Task Instructions

**Wrong:**
```markdown
# Task 0: Setup
## Steps
1. Implement database migration utility
2. Write helper functions for coordination
```

**Correct:**
```markdown
# Task 0: Setup
## Steps
1. Create orchestration_tasks table via comms-link execute
2. Create orchestration_messages table via comms-link execute
3. Verify tables with SELECT queries
```
</core>

<context>
Conductor tasks coordinate — they do not write application code. Code belongs in musician tasks.
</context>

<core>
### 12. Forgetting to Terminate Background Subagent

**Wrong:** Task completes or enters review checkpoint without calling `TaskStop(task_id=[subagent-id])` on the background monitoring subagent.

**Correct:** Always terminate the background monitoring subagent before:
- Entering review checkpoint (before launching blocking review subagent)
- Completing the task (before final state update)
- Exiting on error (before setting state to 'exited')
</core>

<context>
Unterminated background subagents become zombie processes that continue polling the database, consuming resources and potentially interfering with subsequent task attempts. The parallel task template shows `TaskStop(task_id=[subagent-id])` at review and completion points.
</context>
</section>

<section id="quality">
<core>
## Quality Anti-Patterns

### 13. Missing Tests

**Wrong:** Task instruction has no testing requirements section.

**Correct:** Every task specifies what tests to run, expected outcomes, and test file locations.

### 14. Placeholder Text Left In

**Wrong:** Instructions contain `[TODO]`, `[fill in]`, `[placeholder]`, or unfilled `[brackets]`.

**Correct:** All placeholders replaced with actual values or explicit template markers that the musician session fills at runtime (like `$CLAUDE_SESSION_ID`, `[git SHA]`).
</core>

<context>
Runtime placeholders that are acceptable:
- `$CLAUDE_SESSION_ID` — injected by SessionStart hook
- `[task-id]` — filled by musician session at start
- `[git SHA]` — filled after commit
- `[actual]k tokens` — filled at completion
- `YYYY-MM-DD` — filled at execution time
</context>

<core>
### 15. Forgetting Proposal Requirements

**Wrong:** Task that discovers new patterns has no RAG proposal in deliverables.

**Correct:** Mark proposals as REQUIRED when the task involves:
- New patterns or conventions → RAG proposal
- Schema changes → database proposal
- API changes → API proposal
- Convention changes → spec proposal

### 16. Invalid State References

**Wrong:** References to `waiting`, `orchestrating`, `coordination_complete`, or `status` column.

**Correct:** Use only the 11 valid states: `watching`, `reviewing`, `exit_requested`, `complete`, `working`, `needs_review`, `review_approved`, `review_failed`, `error`, `fix_proposed`, `exited`. Use `state` column only (no `status`).

### 17. Missing Context Estimates

**Wrong:**
```markdown
### Step 3: Read Source Files
Read all 6 testing documentation files...
```

**Correct:**
```markdown
### Step 3: Read Source Files
**Context estimate:** ~40k tokens
- `docs_old/TESTING_GUIDE.md` — ~800 lines (full read)
- `docs_old/COVERAGE_GUIDE.md` — ~400 lines (full read)
**Running total:** ~42k / 140k

Read all 6 testing documentation files...
```
</core>

<context>
Without context estimates, musicians have no way to gauge remaining budget. Steps that exceed 140k cause silent context truncation and lost instructions.
</context>

<core>
### 18. Using /tmp/ for Temporary Files

**Wrong:**
```markdown
Save intermediate output to `/tmp/scratch.md`
```

**Correct:**
```markdown
Save intermediate output to `temp/scratch.md`
```
</core>

<context>
`temp/` (project root) is a symlink to `/tmp/remindly/` and provides project-relative paths. Using `/tmp/` directly creates files outside the project and bypasses the established temp directory convention.
</context>
</section>

<section id="format">
<core>
## Format Anti-Patterns (Hybrid Document Structure)

### 19. Naked Text in Tier 3 Documents

**Wrong:**
```xml
<section id="objective">
## Objective
Build the notification service.
This is important because...
</section>
```

**Correct:**
```xml
<section id="objective">
<core>
## Objective
Build the notification service.
</core>
<context>
This is important because...
</context>
</section>
```
</core>

<context>
In Tier 3 documents, all text must be inside an authority tag (`<core>`, `<mandatory>`, `<guidance>`, `<context>`). No unmarked markdown floating inside a `<section>`. This forces explicit categorization of every paragraph.
</context>

<core>
### 20. Invented Tags

**Wrong:**
```xml
<warning>Do not skip this step.</warning>
<note>This is optional but recommended.</note>
<important>Always check heartbeats.</important>
```

**Correct:**
```xml
<mandatory>Do not skip this step.</mandatory>
<guidance>This is optional but recommended.</guidance>
<mandatory>Always check heartbeats.</mandatory>
```
</core>

<context>
The tag allowlist is fixed: `mandatory`, `guidance`, `context`, `sections`, `section`, `core`, `template`, `reference`, `checkpoint`, `metadata`, and document-level wrappers. All other tags are forbidden.
</context>

<core>
### 21. Missing Sections Index

**Wrong:** A Tier 2/3 document with no `<sections>` index after metadata/frontmatter.

**Correct:** Every Tier 2 and Tier 3 document must have a `<sections>` index listing all `<section id="...">` values in document order. If a section exists but isn't in the index, it's a bug.

### 22. Using [STRICT]/[FLEXIBLE] Instead of Tags

**Wrong:**
```markdown
## Initialization [STRICT]
## Work Execution [FLEXIBLE]
```

**Correct:**
```xml
<section id="initialization">
<mandatory>
[Non-negotiable content — must follow exactly]
</mandatory>
</section>

<section id="execution">
<core>
[Essential content — can adapt to task context]
</core>
<guidance>
[Recommended approaches]
</guidance>
</section>
```
</core>

<context>
The `[STRICT]`/`[FLEXIBLE]` convention is replaced by the hybrid document structure's authority tags. `[STRICT]` → `<mandatory>` (non-negotiable). `[FLEXIBLE]` → `<core>` or `<guidance>` (adaptable). Specific SQL and code patterns use `<template follow="exact">` for verbatim reproduction.
</context>

<core>
### 23. Reading Full Plan Instead of Phase Section

**Wrong:**
```markdown
## Instructions
1. Read the implementation plan at `{PLAN_PATH}`
2. Extract tasks for Phase 2
```

**Correct:**
```markdown
## Instructions
1. Read lines {LINE_START}-{LINE_END} of the plan at `{PLAN_PATH}`
2. This is your assigned phase section — it is self-contained
```
</core>

<context>
The Arranger pipeline produces self-contained phase sections with sentinel markers and a line range index. The copyist reads only its assigned section by line range, not the full plan. Reading the full plan wastes context and defeats the self-containment design.
</context>
</section>

<section id="anti-pattern-guard-clause">
<core>
### 24. Overly Permissive Claim Guard Clause

**Wrong:** `AND state NOT IN ('working', 'complete', 'exited')` — allows claiming from 8 states including `needs_review`, `error`, and `review_approved`, potentially stomping in-progress work.

**Correct:** `AND state IN ('watching', 'fix_proposed', 'exit_requested')` — only 3 states where claiming is safe. The Conductor ensures tasks are in a claimable state before launching musicians.
</core>

<context>
The `NOT IN` formulation is dangerous because it implicitly allows claiming from any new state added to the schema. The `IN` formulation is explicit and safe — only the documented claimable states permit a new session to take ownership.
</context>
</section>

<section id="anti-pattern-polling-intervals">
<core>
### 25. Hardcoded Polling Intervals That Diverge From Musician Constants

**Wrong:** Embedding arbitrary polling intervals (e.g., "Check every 8 seconds") in subagent prompt templates without checking the Musician's timing constants.

**Correct:** Use the Musician's documented intervals — background watcher: 15 seconds, pause/blocking watcher: 10 seconds. Blocking review timeout: 90 iterations (15 minutes).
</core>

<context>
The Musician skill defines canonical timing constants. Since task instructions use `<template follow="exact">`, the Copyist's embedded intervals override the Musician's own knowledge. Mismatched intervals create unnecessary database load (too fast) or delayed response (too slow).
</context>
</section>

</skill>
