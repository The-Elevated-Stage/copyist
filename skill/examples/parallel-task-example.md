<skill name="copyist-parallel-example" version="2.0">

<metadata>
type: example
parent-skill: copyist
tier: 3
description: Completed parallel task instruction demonstrating Tier 3 task-instruction format (adapted from real usage — testing documentation extraction task)
</metadata>

<sections>
- example-content
</sections>

<section id="example-content">
<context>
This is a concrete example of a parallel task instruction file in Tier 3 `<task-instruction>` format. It demonstrates every required section including review checkpoint, post-review execution, success criteria, background subagent, proper SQL patterns with `message_type`, `$CLAUDE_SESSION_ID` usage, context estimates, and Tier 3 authority tag compliance. Use this as a reference when generating parallel task instructions.
</context>

<core>
## Example: Task 03 — Extract Testing Documentation

```xml
<task-instruction id="task-03" type="parallel">

<metadata>
parallel-safe: true (with Tasks 4, 5, 6)
dependencies: task-02 complete
token-estimate: ~75k
review-checkpoints: 1 (after extraction proposal, before finalization)
</metadata>

<sections>
- mandatory-rules
- danger-files
- objective
- prerequisites
- bootstrap
- execution
- rag-proposals
- review-checkpoint
- post-review-execution
- verification
- testing
- completion
- deliverables
- success-criteria
- error-recovery
- reference
</sections>

<section id="mandatory-rules">
<mandatory>
- Must launch background message-watcher before any work step
- Must check system message context usage after every tool response
- Must use `temp/` for scratch files — never `/tmp/` directly
- Must follow all `<template follow="exact">` blocks verbatim
- Context budget: 140k tokens for file reads, 170k total session cap — prepare handoff at 70% usage
- Must include all 11 review message fields in checkpoint messages
- Error recovery: every error must be reported to database before retry
- Must include heartbeat updates after every major step
</mandatory>
</section>

<section id="danger-files">
<mandatory>
## Danger Files

N/A — no shared files identified for this task.
</mandatory>
</section>

<section id="objective">
<core>
## Objective

Extract testing patterns from 6 testing documentation files in docs_old/ to knowledge-base/testing/. Create extraction proposal with valid/outdated/anti-pattern markers. Create consolidated human-readable testing-guide.md in reference/. Verify YAML frontmatter metadata before RAG ingestion.

### Critical Success Criteria
1. All 6 source files read and analyzed
2. Extraction proposal approved by conductor before creating final files
3. RAG files have complete YAML frontmatter and status markers
4. Reference guide has warning label about RAG being authoritative
5. Learnings captured in proposal format
</core>

<context>
This is a documentation extraction task. Source files contain testing patterns written across 6 legacy docs. Each pattern must be evaluated as valid, outdated, or anti-pattern, then structured as individual RAG files with YAML frontmatter.

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
-- Verify Task 2 complete
SELECT state FROM orchestration_tasks WHERE task_id = 'task-02';
-- Expected: 'complete'
```
</template>

```bash
# Verify knowledge-base/testing/ directory exists
test -d docs/knowledge-base/testing || echo "ERROR: knowledge-base/testing/ not found"
# Expected: no output (directory exists)

# Verify source files exist
ls -lh docs_old/{TESTING_GUIDE.md,TESTING_REQUIREMENTS.md,TESTING_QUICK_REFERENCE.md,COVERAGE_GUIDE.md,E2E_TEST_SETUP.md,WIDGET_TESTING_PATTERNS.md} 2>&1
# Expected: All 6 files exist, total ~117KB
```
</core>
</section>

<section id="bootstrap">
<mandatory>
## Initialization

The stop hook activates automatically once `session_id` is written to `orchestration_tasks` during the task claim below. No manual hook setup is required.
</mandatory>

<core>
### Step 1: Claim Task + Initialize Database

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'working',
    session_id = '$CLAUDE_SESSION_ID',
    worked_by = '$CLAUDE_SESSION_ID',
    started_at = datetime('now'),
    last_heartbeat = datetime('now'),
    retry_count = 0
WHERE task_id = 'task-03'
  AND state NOT IN ('working', 'complete', 'exited');
```
</template>

<checkpoint>
Verify claim succeeded:
```sql
SELECT state, session_id FROM orchestration_tasks WHERE task_id = 'task-03';
-- Expected: state='working', session_id matches $CLAUDE_SESSION_ID
```
If failed, go to error-recovery section.
</checkpoint>

### Step 2: Launch Background Subagent

<mandatory>Background watcher must be running before any work step.</mandatory>

<template follow="exact">
```python
Task(
    description="Monitor conductor messages for task-03",
    prompt="""Monitor coordination database for task-03.

Check every 8 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = 'task-03'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = 'task-03' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

Exit conditions:
- State changes from 'working' (indicates conductor intervention)
- New message from task-00 appears
- Max iterations: 500

When exiting:
- Report final state
- Include latest message if any
- Return immediately without further action""",
    subagent_type="general-purpose",
    run_in_background=True
)
```
</template>

<checkpoint>
Verify background watcher is running (save task ID).
Do not proceed to execution until confirmed.
</checkpoint>
</core>
</section>

<section id="execution">
<core>
## Work Execution

### Step 3: Read Source Files

**Context estimate:** ~40k tokens
- `docs_old/TESTING_GUIDE.md` — ~800 lines (full read)
- `docs_old/TESTING_REQUIREMENTS.md` — ~400 lines (full read)
- `docs_old/TESTING_QUICK_REFERENCE.md` — ~150 lines (full read)
- `docs_old/COVERAGE_GUIDE.md` — ~400 lines (full read)
- `docs_old/E2E_TEST_SETUP.md` — ~350 lines (full read)
- `docs_old/WIDGET_TESTING_PATTERNS.md` — ~250 lines (full read)
**Running total:** ~40k / 140k

<mandatory>Background message-watcher must be running at all times.</mandatory>
If watcher is not running, relaunch immediately before continuing.

Read all 6 testing documentation files.

**For each file:**
1. Use Read tool to load content
2. Identify distinct testing patterns
3. Note overlap between files
4. Flag outdated or anti-pattern approaches

**Expected patterns to extract:**
- Test structure patterns (arrange-act-assert)
- Widget testing patterns (Flutter-specific)
- Mocking patterns
- Coverage requirements
- E2E test setup procedures
- Common pitfalls and anti-patterns

```python
result = TaskOutput(task_id=[subagent-id], block=False, timeout=100)
if result.completed:
    # Process message, relaunch subagent
    pass
```

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-03';
```
</template>
</core>
</section>

<section id="rag-proposals">
<core>
## RAG Proposal Creation

### Step 4: Create RAG Extraction Proposals (One Per File)

**Context estimate:** ~15k tokens
- Writing [N] proposal files, ~50 lines each
- RAG queries for pre-screening (~1k per query)
**Running total:** ~55k / 140k

<mandatory>Do NOT create RAG files directly in `docs/knowledge-base/`. Instead, create PROPOSALS in `docs/implementation/proposals/` that contain the RAG file content.</mandatory>

<guidance>
One proposal per file enables fine-grained extraction/exclusion by conductor. Allows rejection of individual files without affecting others.

**Pre-screening (before creating each proposal):**
1. Query KB: `query_documents("[pattern topic]", limit=10)` at 0.4 relevance threshold
2. If matches found (score < 0.3): Record in RAG Match List, consider updating existing file instead
3. If no matches (> 0.4): Proceed with new file proposal
</guidance>

**For [N] RAG files:** Create [N] separate proposal files:
- `docs/implementation/proposals/task-03-rag-test-structure-patterns.md`
- `docs/implementation/proposals/task-03-rag-widget-testing.md`
- `docs/implementation/proposals/task-03-rag-mocking-patterns.md`
- ... (one for each identified pattern)

**Also create extraction summary proposal:**
`docs/implementation/proposals/task-03-testing-extraction.md`

<template follow="format">
```markdown
# Task 3: Testing Documentation Extraction Proposal

**Date:** YYYY-MM-DD
**Source files:** 6 testing docs (117KB total)
**Target:** docs/knowledge-base/testing/

## Extraction Summary

**Total patterns identified:** [count]
**Status breakdown:**
- Valid (current best practices): [count]
- Outdated (deprecated but documented): [count]
- Anti-pattern (explicitly avoid): [count]

## Pattern Inventory

### Pattern 1: [Name]
**Status:** Valid / Outdated / Anti-pattern
**Source:** [file.md, section]
**RAG file:** testing/[pattern-name].md
**Content preview:** [Key excerpt]

[Continue for all patterns...]

## Quality Concerns

[Any issues found during analysis]
```
</template>

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-03';
```
</template>
</core>
</section>

<section id="review-checkpoint">
<mandatory>
## Review Checkpoint

All review checkpoint content is non-negotiable.
</mandatory>

<core>
### Step 5: Request Review

**Commit work so far:**

<template follow="exact">
```bash
git add docs/implementation/proposals/task-03-*.md

git commit -m "$(cat <<'EOF'
task-03: testing patterns extraction proposal

- Analyzed 6 testing documentation files (117KB)
- Identified [N] distinct patterns
- Categorized as valid/outdated/anti-pattern
- Ready for conductor review

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```
</template>

**Update database (message FIRST, then state):**

<mandatory>All 11 review message fields are required. No omissions.</mandatory>

<template follow="exact">
```sql
-- Message FIRST
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-03', '$CLAUDE_SESSION_ID',
'CHECKPOINT 1: REVIEW REQUEST — Testing patterns extraction proposal ready

Context Usage: [X]%
Self-Correction: NO
Deviations: 0 (none)
Agents Remaining: 1 (background monitor)
Proposal: docs/implementation/proposals/task-03-testing-extraction.md
Summary: [N] patterns identified across 6 source files, categorized as valid/outdated/anti-pattern
Files Modified: [N]
Tests: N/A (documentation task)
Smoothness: [0-9]
Reason: Extraction proposal needs conductor approval before creating final RAG files

Review focus:
- Pattern categorization accuracy (valid/outdated/anti-pattern)
- Completeness (any patterns missed?)
- Extraction approach alignment with design

Commits: [SHA]',
'review_request');

-- Then state
UPDATE orchestration_tasks
SET state = 'needs_review',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</template>

### Step 6: Wait for Review

**Terminate background subagent:**
```python
TaskStop(task_id=[subagent-id])
```

**Launch BLOCKING subagent to wait for review:**

<template follow="exact">
```python
Task(
    description="Wait for review approval for task-03",
    prompt="""Wait for conductor review of task-03.

Poll every 10 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = 'task-03'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = 'task-03' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

Exit when state changes from 'needs_review' to:
- 'review_approved' -> Report: APPROVED with feedback
- 'review_failed' -> Report: FAILED with feedback
- 'fix_proposed' -> Report: FIX PROPOSED with instructions

Include latest conductor message in response.

Max iterations: 90 (15 minutes)
If timeout: Report TIMEOUT""",
    subagent_type="general-purpose",
    run_in_background=False
)
```
</template>

**Process review result:**
```python
if result.contains("APPROVED"):
    # Read feedback, update state, continue
    pass
elif result.contains("FAILED"):
    # Read feedback, revise work, return to review request
    pass
elif result.contains("TIMEOUT"):
    # Set state to error, alert user
    pass
```

**If APPROVED, resume working:**

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'working',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</template>

<mandatory>Relaunch background monitoring subagent (same as Step 2) after review checkpoint.</mandatory>
</core>
</section>

<section id="post-review-execution">
<core>
## Post-Review Execution

### Step 7: Create RAG Proposal Files

**Context estimate:** ~15k tokens
- Writing [N] RAG proposal files from approved extraction, ~40 lines each
**Running total:** ~70k / 140k

For each approved pattern, create a proposal file in `docs/implementation/proposals/rag-testing-[pattern-name].md`:

<template follow="format">
```markdown
# RAG Proposal: testing/[pattern-name]

**Target:** docs/knowledge-base/testing/[pattern-name].md
**Source:** docs_old/[original-file].md
**Status:** valid | outdated | anti-pattern
**Extracted by:** task-03

## Proposed Content

```yaml
---
id: testing/[pattern-name]
type: pattern
category: testing
created: YYYY-MM-DD
status: valid | outdated | anti-pattern
project: remindly
tags: [testing, flutter, etc.]
source: docs_old/[original-file].md
extracted_from: task-03
---
```

# [Pattern Name]

**Status:** Valid / Outdated / Anti-pattern

[Pattern description and guidance]

## When to Use
[Applicability]

## Example
[Code example if applicable]

## Common Pitfalls
[What to avoid]
```
</template>

<mandatory>Musicians must NOT call `ingest_file` or `ingest_data` directly. Create proposal files and list them in deliverables — the conductor handles ingestion after review.</mandatory>

```python
result = TaskOutput(task_id=[subagent-id], block=False, timeout=100)
if result.completed:
    # Process message, relaunch subagent
    pass
```

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-03';
```
</template>

### Step 8: Create Reference Guide

**Context estimate:** ~5k tokens
- 1 consolidated guide to write, ~100 lines
**Running total:** ~75k / 140k

Create `docs/reference/testing-guide.md` with warning label at top:

```markdown
> **IMPORTANT:** This is a human-readable reference guide. For AI/RAG queries, use
> `docs/knowledge-base/testing/` which contains the authoritative, structured testing
> patterns. This guide may become outdated.
```

Consolidate all valid patterns into organized guide with table of contents.

### Step 9: Verify Proposals Complete

<mandatory>All RAG proposals must be listed in deliverables before completion.</mandatory>

Verify all [N] RAG proposal files exist in `docs/implementation/proposals/rag-testing-*.md` and each contains complete content with YAML frontmatter. The conductor will handle ingestion after reviewing the proposals.
</core>
</section>

<section id="verification">
<core>
## Verification Checklist

- [ ] All 6 source files read successfully
      **Verify:** `ls docs_old/{TESTING_GUIDE.md,TESTING_REQUIREMENTS.md,TESTING_QUICK_REFERENCE.md,COVERAGE_GUIDE.md,E2E_TEST_SETUP.md,WIDGET_TESTING_PATTERNS.md} 2>&1 | grep -c "No such file"`
      **Expected:** 0
      **If failed:** Check docs_old/ path

- [ ] Extraction proposal created and approved
      **Verify:** `test -f docs/implementation/proposals/task-03-testing-extraction.md && echo "EXISTS"`
      **Expected:** EXISTS
      **If failed:** Re-check review checkpoint results

- [ ] All RAG proposal files have complete content
      **Verify:** `for f in docs/implementation/proposals/rag-testing-*.md; do grep -q "^---" "$f" && grep -q "^id:" "$f" && grep -q "^status:" "$f" || echo "Missing metadata: $f"; done`
      **Expected:** No output
      **If failed:** Add missing frontmatter fields

- [ ] Reference guide created with warning label
      **Verify:** `test -f docs/reference/testing-guide.md && grep -q "IMPORTANT.*knowledge-base.*authoritative" docs/reference/testing-guide.md`
      **Expected:** File exists with warning
      **If failed:** Add warning label

- [ ] Proposal count matches extraction
      **Verify:** `ls -1 docs/implementation/proposals/rag-testing-*.md | wc -l`
      **Expected:** Matches pattern count in approved extraction proposal
      **If failed:** Check for missing proposals

<mandatory>All checks must pass before proceeding to completion.</mandatory>

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = 'task-03';
```
</template>
</core>
</section>

<section id="testing">
<core>
## Testing Requirements

### Manual Verification

- [ ] All RAG proposal files contain valid YAML frontmatter and complete content
- [ ] Reference guide has coherent structure with table of contents
- [ ] No broken cross-references between proposal files
</core>
</section>

<section id="completion">
<mandatory>
## Completion

All completion steps are non-negotiable.
</mandatory>

<core>
### Step 10: Commit Changes

<template follow="exact">
```bash
git add docs/implementation/proposals/rag-testing-*.md \
        docs/implementation/proposals/task-03-*.md \
        docs/reference/testing-guide.md

git commit -m "$(cat <<'EOF'
task-03: extract testing patterns from 6 source files

Extraction:
- Source: 6 testing docs (117KB total)
- Created [N] RAG proposal files in proposals/
- Status: [N] valid, [N] outdated, [N] anti-pattern

Reference:
- Created consolidated testing-guide.md in reference/
- Added warning label (knowledge-base is authoritative)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```
</template>

### Step 11: Update Database

**Terminate background subagent:**
```python
TaskStop(task_id=[subagent-id])
```

<mandatory>Message FIRST, then state + metadata.</mandatory>

<template follow="exact">
```sql
-- Message FIRST
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-03', '$CLAUDE_SESSION_ID',
'TASK COMPLETE: Testing patterns extracted

Smoothness: [0-9]
Context Usage: [X]%
Self-Correction: [YES/NO]
Deviations: [count]
Files Modified: [count]
Tests: N/A (documentation task)
Key Outputs:
  - docs/implementation/proposals/rag-testing-*.md ([N] proposals created)
  - docs/reference/testing-guide.md (created)
  - docs/implementation/proposals/task-03-testing-extraction.md (created)

Report: docs/implementation/reports/task-03-report.md
Commit: [SHA]
All verification checks: PASSED',
'completion');

-- Then state + metadata
UPDATE orchestration_tasks
SET state = 'complete',
    completed_at = datetime('now'),
    report_path = 'docs/implementation/reports/task-03-report.md',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</template>

### Step 12: Generate Completion Report

**Save to:** `docs/implementation/reports/task-03-report.md`

<template follow="format">
```markdown
# Task 03 Completion Report

**Date:** YYYY-MM-DD
**Status:** Complete
**Token usage:** ~[actual]k tokens (estimated: 75k)

---

## Summary

Extracted testing patterns from 6 source files (117KB) into structured RAG knowledge base. Created [N] pattern files with YAML frontmatter. Consolidated reference guide created.

---

## Verification Results

- PASS: All 6 source files read (6/6)
- PASS: Extraction proposal approved
- PASS: RAG files have complete YAML frontmatter
- PASS: Reference guide has warning label
- PASS: File count matches proposal
- PASS: RAG ingestion verified

---

## Review Checkpoint

**Smoothness score:** [0-9]
**Review outcome:** Approved
**Feedback:** [conductor feedback]

---

## Files Created/Modified

**Created:**
- docs/knowledge-base/testing/*.md ([N] files)
- docs/reference/testing-guide.md
- docs/implementation/proposals/task-03-testing-extraction.md
- docs/implementation/proposals/task-03-learnings.md
- docs/implementation/reports/task-03-report.md

**Modified:**
- None

---

## Issues Encountered

[Problems and resolutions, or "None"]

---

## Commit

**SHA:** [hash]
**Files:** [count] added
```
</template>
</core>
</section>

<section id="deliverables">
<core>
## Deliverables

### Code (REQUIRED)
- [ ] RAG files in docs/knowledge-base/testing/ with YAML frontmatter
- [ ] Reference guide at docs/reference/testing-guide.md

### Reports (REQUIRED)
- [ ] Completion report at `docs/implementation/reports/task-03-report.md`

### Proposals (REQUIRED when applicable)
- [ ] RAG proposal: required — individual proposal files at `docs/implementation/proposals/task-03-rag-*.md`
- [ ] Extraction summary: required — `docs/implementation/proposals/task-03-testing-extraction.md`
- [ ] Learnings proposal: required — `docs/implementation/proposals/task-03-learnings.md`
</core>
</section>

<section id="success-criteria">
<core>
## Success Criteria

- [ ] All 6 source files read and analyzed
- [ ] Extraction proposal approved by conductor
- [ ] RAG files created with complete metadata
- [ ] Reference guide created with warning label
- [ ] All verification checks passed
- [ ] Completion report generated
- [ ] Database state updated to 'complete'
- [ ] Background subagent terminated
- [ ] Conductor notified via orchestration_messages
</core>
</section>

<section id="error-recovery">
<mandatory>
## Error Recovery

Every error must be reported to the database before any retry. Silent retries are task failures.
</mandatory>

<core>
**If errors occur during execution:**

1. **Capture error details:**

<template follow="exact">
```sql
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('task-03', '$CLAUDE_SESSION_ID',
'ERROR (Retry [N]/5): [description]

Step: [which step failed]
Error: [specific message]
Context: [relevant state]

Proposed fix: [what will be tried]',
'error');

UPDATE orchestration_tasks
SET state = 'error',
    retry_count = retry_count + 1,
    last_error = '[error summary]',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
```
</template>

2. **Wait for conductor fix proposal:**
   Launch blocking subagent to wait for state = 'fix_proposed'.
   Read conductor's fix instructions from orchestration_messages.
   Apply fix, update state back to 'working', retry failed step.

3. **If retry count reaches 5:**

<mandatory>Session must exit after 5th retry failure.</mandatory>

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'exited',
    last_heartbeat = datetime('now')
WHERE task_id = 'task-03';
-- Session will terminate via hook exit criteria
```
</template>
</core>
</section>

<section id="reference">
<core>
## Reference

**Implementation plan:** docs/plans/implementation/2026-02-02-docs-reorganization-implementation.md (Section: Task 3)
**Design document:** docs/plans/designs/2026-02-01-docs-reorganization-design.md (Section 8: Extraction Process)
</core>
</section>

</task-instruction>
```
</core>
</section>

</skill>
