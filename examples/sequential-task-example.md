<skill name="copyist-sequential-example" version="2.0">

<metadata>
type: example
parent-skill: copyist
tier: 3
description: Completed sequential task instruction demonstrating Tier 3 task-instruction format (adapted from real usage — docs reorganization directory creation task)
</metadata>

<sections>
- example-content
</sections>

<section id="example-content">
<context>
This is a concrete example of a sequential task instruction file in Tier 3 `<task-instruction>` format. It demonstrates every required section, proper SQL patterns with `message_type`, `$CLAUDE_SESSION_ID` usage, context estimates, and Tier 3 authority tag compliance. Use this as a reference when generating sequential task instructions.
</context>

<core>
## Example: Task 01 — Directory Creation & README System

```xml
<task-instruction id="task-01" type="sequential">

<metadata>
parallel-safe: false
dependencies: task-00 complete
token-estimate: ~95k
review-checkpoints: 0
</metadata>

<sections>
- mandatory-rules
- objective
- prerequisites
- bootstrap
- execution
- rag-proposals
- verification
- testing
- completion
- deliverables
- error-recovery
- reference
</sections>

<section id="mandatory-rules">
<mandatory>
- Must check for conductor messages between major work steps
- Must use `temp/` for scratch files — never `/tmp/` directly
- Must follow all `<template follow="exact">` blocks verbatim
- Must include heartbeat updates after every major step
- Must report errors to database before any retry attempt
- Context budget: 140k tokens for file reads, 170k total session cap
</mandatory>
</section>

<section id="objective">
<core>
## Objective

Establish the complete documentation directory structure for the Remindly project. This task creates the base directories, subdirectories, and 10 README files that all subsequent tasks depend on.

### Critical Success Criteria
1. All base directories created (knowledge-base/, reference/, specs/, plans/, implementation/, scratchpad/, archive/)
2. All 10 README files written with complete specifications
3. Scratchpad files initialized with header templates
4. Learnings proposal created if patterns discovered
</core>

<context>
Task 1 is a foundation task — all directories and README specifications are defined here. The dual-documentation system uses knowledge-base/ for RAG-queryable patterns (one concept per file, YAML frontmatter) and reference/ for human-readable guides (compiled from RAG at release points).

This task instruction is self-contained. All necessary information is included below.
</context>
</section>

<section id="prerequisites">
<core>
## Prerequisites

### Pre-Flight Checks

<mandatory>All prerequisites must pass before claiming task.</mandatory>

<template follow="exact">
```sql
-- Verify Task 0 complete
SELECT state FROM orchestration_tasks WHERE task_id = 'task-00';
-- Expected: 'complete'
```
</template>

```bash
# Verify project root
test -d /home/kyle/claude/remindly/docs && echo "docs/ exists" || echo "ERROR: docs/ not found"
# Expected: docs/ exists
```
</core>
</section>

<section id="bootstrap">
<core>
## Initialization

### Claim Task

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'working',
    session_id = '$CLAUDE_SESSION_ID',
    worked_by = '$CLAUDE_SESSION_ID',
    started_at = datetime('now'),
    last_heartbeat = datetime('now'),
    retry_count = 0
WHERE task_id = 'task-01'
  AND state NOT IN ('working', 'complete', 'exited');
```
</template>

<checkpoint>
Verify claim succeeded (check that state is now 'working' and session_id matches).
If failed, go to error-recovery section.
</checkpoint>
</core>
</section>

<section id="execution">
<core>
## Work Execution

### Step 1: Rename and Create Base Directories

**Context estimate:** ~2k tokens
- Shell commands only, no file reads
**Running total:** ~2k / 140k

**Rename guidelines/ to knowledge-base/:**
```bash
cd /home/kyle/claude/remindly
mv docs/guidelines docs/knowledge-base
```

**Create missing base directories:**
```bash
mkdir -p docs/reference
mkdir -p docs/specs/{active,implemented}
mkdir -p docs/plans/implementation/tasks
mkdir -p docs/implementation/{reports,proposals}
mkdir -p docs/scratchpad
mkdir -p docs/archive/{plans/{designs,implementation},implementation/reports,meta,obsolete}
```

**Expected outcome:**
- 7 base directories under docs/
- Nested archive structure created
- guidelines/ renamed to knowledge-base/

**If issues arise:**
- If guidelines/ already renamed, verify knowledge-base/ exists
- If mkdir fails, check permissions on docs/

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-01';
```
</template>

### Step 2: Create knowledge-base/ Subdirectories

**Context estimate:** ~1k tokens
- Shell commands only, no file reads
**Running total:** ~3k / 140k

```bash
mkdir -p docs/knowledge-base/{testing,api,database,plans,templates}
```

<guidance>
These subdirectories are created empty — subsequent extraction tasks (3-6) will populate them.
</guidance>

**Expected outcome:**
- 8 subdirectories in knowledge-base/ (3 existing + 5 new)

<template follow="exact">
```sql
-- Check for conductor messages (non-blocking)
SELECT message, timestamp FROM orchestration_messages
WHERE task_id = 'task-01' AND from_session = 'task-00'
ORDER BY timestamp DESC LIMIT 1;
```
</template>

### Step 3: Create All 10 README Files

**Context estimate:** ~30k tokens
- 10 README files to write, ~50 lines each (~500 lines output)
- Reference reads: `docs/plans/designs/2026-02-01-docs-reorganization-design.md` — ~200 lines (sections 3, 5)
**Running total:** ~33k / 140k

**Complete README file list:**
1. `docs/README.md` — Main index, dual-documentation system explanation
2. `docs/knowledge-base/README.md` — RAG system, YAML metadata standard, granularity principle
3. `docs/reference/README.md` — Compilation workflow, warning label requirement
4. `docs/specs/README.md` — Active vs implemented subdirectories
5. `docs/plans/README.md` — Design/implementation plans lifecycle
6. `docs/plans/designs/README.md` — System vs feature designs naming
7. `docs/implementation/README.md` — Reports and proposals overview
8. `docs/implementation/proposals/README.md` — Proposal template, flat structure deviation
9. `docs/scratchpad/README.md` — Active tracking workflow
10. `docs/archive/README.md` — Archive rules, nested structure

**Key content requirements:**
- docs/knowledge-base/README.md must include YAML frontmatter metadata standard
- docs/reference/README.md must include warning label requirement for all reference docs
- docs/implementation/proposals/README.md must document flat structure deviation from design

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-01';
```
</template>

### Step 4: Initialize Scratchpad Files

**Context estimate:** ~3k tokens
- 5 small files to create, ~10 lines each
**Running total:** ~36k / 140k

```bash
touch docs/scratchpad/user.txt
```

Create `docs/scratchpad/bugs.md`, `features.md`, `ideas.md`, `tech-debt.md` — each with header comments showing quick-add commands.

**Expected outcome:**
- user.txt is empty (universal capture)
- 4 categorized files have header templates

### Step 5: Create Learnings Proposal

**Context estimate:** ~5k tokens
- 1 proposal file to write, ~40 lines
**Running total:** ~41k / 140k

<guidance>
If any patterns or conventions were discovered during execution, create:
`docs/implementation/proposals/task-01-learnings.md`

Common proposal triggers for this task:
- Directory structure decision patterns
- README completeness criteria
- Documentation organization principles
</guidance>

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-01';
```
</template>
</core>
</section>

<section id="rag-proposals">
<core>
## RAG Proposal Creation

N/A — this task creates directory structure and READMEs, no RAG extraction work involved.
</core>
</section>

<section id="verification">
<core>
## Verification Checklist

- [ ] All base directories exist
      **Verify:** `ls -d docs/{knowledge-base,reference,specs,plans,implementation,scratchpad,archive} 2>&1`
      **Expected:** All 7 directories listed, no errors
      **If failed:** Re-run mkdir commands from Step 1

- [ ] All 10 README files created with substantial content
      **Verify:** `find docs -name "README.md" -type f | wc -l`
      **Expected:** 10
      **If failed:** Check which READMEs are missing

- [ ] README files have >= 10 lines each
      **Verify:** `find docs -name "README.md" -type f -exec wc -l {} \; | awk '{if ($1 < 10) print $2 " only has " $1 " lines"}'`
      **Expected:** No output
      **If failed:** Flesh out thin READMEs

- [ ] guidelines/ renamed to knowledge-base/
      **Verify:** `test -d docs/knowledge-base && test ! -d docs/guidelines && echo "SUCCESS"`
      **Expected:** "SUCCESS"
      **If failed:** Check if rename completed

- [ ] Flat proposals structure (no subdirectories)
      **Verify:** `find docs/implementation/proposals -mindepth 1 -type d | wc -l`
      **Expected:** 0
      **If failed:** Remove any subdirectories

- [ ] Scratchpad files initialized
      **Verify:** `ls docs/scratchpad/{user.txt,bugs.md,features.md,ideas.md,tech-debt.md} 2>&1`
      **Expected:** All 5 files listed
      **If failed:** Re-run Step 4

<mandatory>All checks must pass before proceeding to completion.</mandatory>
</core>
</section>

<section id="testing">
<core>
## Testing Requirements

### Manual Verification

- [ ] docs/knowledge-base/README.md contains YAML metadata standard example
- [ ] docs/reference/README.md contains warning label requirement
- [ ] docs/implementation/proposals/README.md documents flat structure deviation
- [ ] No subdirectory READMEs in knowledge-base/ (only root README)
- [ ] Empty knowledge-base subdirectories (testing/, api/, database/, plans/, templates/) contain no files
</core>
</section>

<section id="completion">
<core>
## Completion

### Commit Changes

<template follow="exact">
```bash
git add docs/ docs/implementation/proposals/task-01-learnings.md

git commit -m "$(cat <<'EOF'
task-01: create directory structure and README system

Foundation for documentation reorganization:
- Rename docs/guidelines/ to docs/knowledge-base/
- Create all base directories and subdirectories
- Write 10 README files with complete specifications
- Initialize scratchpad with header templates
- Document flat proposals structure deviation

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```
</template>

### Update Database

<mandatory>Message FIRST, then state change.</mandatory>

<template follow="exact">
```sql
-- Message FIRST
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-01', '$CLAUDE_SESSION_ID',
'TASK COMPLETE: Directory structure and README system created

Summary:
- 7 base directories created
- 10 README files with specifications
- Scratchpad initialized (5 files)
- Learnings proposal created

Report: docs/implementation/reports/task-01-report.md
Commit: [SHA]
All verification checks: PASSED',
'completion');

-- Then state
UPDATE orchestration_tasks
SET state = 'complete',
    completed_at = datetime('now'),
    report_path = 'docs/implementation/reports/task-01-report.md',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-01';
```
</template>

### Completion Report

**Save to:** `docs/implementation/reports/task-01-report.md`

<template follow="format">
```markdown
# Task 01 Completion Report

**Date:** YYYY-MM-DD
**Status:** Complete
**Token usage:** ~[actual]k tokens (estimated: 95k)

---

## Summary

Established complete dual-documentation system. Created all directories, subdirectories, and 10 README files. Foundation ready for extraction tasks (3-6).

---

## Verification Results

- PASS: All base directories exist (7/7)
- PASS: All 10 README files created with >= 10 lines
- PASS: guidelines/ renamed to knowledge-base/
- PASS: Flat proposals structure
- PASS: Scratchpad initialized

---

## Files Created/Modified

**Created:**
- 24 directories
- 10 README files
- 5 scratchpad files
- 1 learnings proposal

**Modified:**
- None (all new structure)

---

## Issues Encountered

None

---

## Commit

**SHA:** [hash]
**Files:** 16 added
```
</template>
</core>
</section>

<section id="deliverables">
<core>
## Deliverables

### Code (REQUIRED)
- [ ] All directories created per specification
- [ ] All 10 README files with complete content
- [ ] Scratchpad files initialized

### Reports (REQUIRED)
- [ ] Completion report at `docs/implementation/reports/task-01-report.md`

### Proposals (REQUIRED when applicable)
- [ ] RAG proposal: not applicable (no RAG patterns created)
- [ ] Learnings proposal: required — `docs/implementation/proposals/task-01-learnings.md`
</core>
</section>

<section id="error-recovery">
<mandatory>
## Error Recovery

Every error must be reported to the database before any retry. Silent retries are task failures.
</mandatory>

<core>
If errors occur during execution:

1. Check conductor messages for guidance
2. Attempt self-recovery if error is straightforward
3. If unable to resolve, report via message:

<template follow="exact">
```sql
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-01', '$CLAUDE_SESSION_ID',
'ERROR (Retry [N]/5): [description]

Step: [which step]
Error: [specific message]
Context: [relevant state]

Proposed fix: [what will be tried]',
'error');

UPDATE orchestration_tasks
SET state = 'error',
    retry_count = retry_count + 1,
    last_error = '[error summary]',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-01';
```
</template>

Then wait for conductor response before continuing.

<mandatory>If retry count reaches 5, session must exit.</mandatory>

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'exited',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-01';
-- Session will terminate via hook exit criteria
```
</template>
</core>
</section>

<section id="reference">
<core>
## Reference

**Implementation plan:** docs/plans/implementation/2026-02-02-docs-reorganization-implementation.md (Section: Task 1)
**Design document:** docs/plans/designs/2026-02-01-docs-reorganization-design.md (Section 3, 5)
</core>
</section>

</task-instruction>
```
</core>
</section>

</skill>
