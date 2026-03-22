<skill name="copyist-parallel-template" version="2.0">

<metadata>
type: template
parent-skill: copyist
tier: 3
output-type: task-instruction
output-tier: 3
</metadata>

<sections>
- usage
- template-body
</sections>

<section id="usage">
<mandatory>
## Usage

Fill in all `[bracketed]` placeholders with task-specific values. Every section in this template must appear in the generated instruction file, in order. If a section does not apply, keep the heading and write "N/A — [reason]". Never skip, merge, or reorder sections.

Sections wrapped in `<mandatory>` are non-negotiable and must be followed exactly. Sections in `<core>` or `<guidance>` can adapt to the task's actual work. Specific SQL blocks and code patterns within any section are wrapped in `<template follow="exact">` — reproduce these verbatim with only placeholder values changed.
</mandatory>

<guidance>
This template produces Tier 3 `<task-instruction>` documents. All text in the output must be inside authority tags (`<core>`, `<mandatory>`, `<guidance>`, `<context>`). No naked markdown outside tags.
</guidance>
</section>

<section id="template-body">
<core>
## Template

<template follow="format">
```xml
<task-instruction id="[task-id]" type="parallel">

<metadata>
parallel-safe: true (with Tasks [list parallel siblings])
dependencies: [task IDs that must complete first]
token-estimate: ~[XX]k
review-checkpoints: [N] ([describe when reviews occur])
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
- Context budget: 140k tokens for file reads, 170k total session cap — prepare handoff at 65% usage
- Must include all 11 review message fields in checkpoint messages
- Error recovery: every error must be reported to database before retry
- Must include heartbeat updates after every major step
</mandatory>
</section>

<section id="danger-files">
<mandatory>
## Danger Files

[If no danger files apply to this task, replace this section's content with: "N/A — no shared files identified for this task."]

### Shared Resources

| File Path | Owner Task | This Task's Access | Mitigation |
|-----------|-----------|-------------------|------------|
| [path] | [task-id] | [read-only / append-only / coordinate] | [strategy] |

### Coordination Rules

- [Specific rules for each danger file — e.g., "Do not modify lines 1-50 of `src/index.ts` — owned by task-03"]
- [Barrel export ordering, shared config sections, etc.]

### DANGER FILE UPDATE Message Template

When modifying a danger file, notify parallel siblings:

```sql
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'DANGER FILE UPDATE: [file-path]
Change: [what was modified]
Impact: [what parallel tasks should know]',
'instruction');
```
</mandatory>
</section>

<section id="objective">
<core>
## Objective

[1-3 sentences describing what this task accomplishes and why it matters]

### Critical Success Criteria
1. [Measurable outcome 1]
2. [Measurable outcome 2]
3. Proposal approved by conductor before [specific milestone]
4. [Continue as needed]
</core>

<context>
[Background — what preceded this task, what's available, plan/design paths for reference only]

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
-- Verify dependencies complete
SELECT state FROM orchestration_tasks WHERE task_id = '[dependency-id]';
-- Expected: 'complete'
```
</template>

```bash
[Any filesystem or environment checks]
# Expected: [what success looks like]
```
</core>
</section>

<section id="bootstrap">
<mandatory>
## Initialization

The stop hook activates automatically once `session_id` is written to `orchestration_tasks` during the task claim below. No manual hook setup is required. Exit criteria (`complete`, `exited`) are defined in `tools/implementation-hook/preset-musician.yaml`.
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
WHERE task_id = '[task-id]'
  AND state IN ('watching', 'fix_proposed', 'exit_requested');
```
</template>

<checkpoint>
Verify claim succeeded:
```sql
SELECT state, session_id FROM orchestration_tasks WHERE task_id = '[task-id]';
-- Expected: state='working', session_id matches $CLAUDE_SESSION_ID
```
If failed, go to error-recovery section.
</checkpoint>

### Step 2: Launch Background Subagent

<mandatory>Background watcher must be running before any work step.</mandatory>

<template follow="exact">
```python
Task(
    description="Monitor conductor messages for [task-id]",
    prompt="""Monitor coordination database for [task-id].

Check every 15 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = '[task-id]'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = '[task-id]' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1
3. Heartbeat: SELECT last_heartbeat FROM orchestration_tasks WHERE task_id = '[task-id]'
   If older than 60 seconds: UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = '[task-id]'

Exit conditions:
- State changes from 'working' (indicates conductor intervention)
- New message from task-00 appears
- Max iterations: 500

When exiting:
- Report final state
- Include latest message if any
- Return immediately without further action""",
    subagent_type="general-purpose",
    model="opus",
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

### Step 3: [First Action]

**Context estimate:** ~[X]k tokens
- `[file-path]` — ~[N] lines ([full read / lines X-Y, section description])
**Running total:** ~[X]k / 140k

<mandatory>Background message-watcher must be running at all times.</mandatory>
If watcher is not running, relaunch immediately before continuing.

[Detailed instructions]

**Expected outcome:**
- [What success looks like]

<guidance>
Between steps, check for conductor messages:
</guidance>

```python
result = TaskOutput(task_id=[subagent-id], block=False, timeout=100)
if result.completed:
    # Process message, relaunch subagent
    pass
```

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = '[task-id]';
```
</template>

### Step 4: [Continue pattern]

[... continue for all pre-review steps]
</core>
</section>

<section id="rag-proposals">
<context>
## RAG Proposal Creation

Include this section only when the task involves RAG/knowledge-base work. If not applicable, keep the heading and write "N/A — [reason]".
</context>

<core>
### Step [N]: Create RAG Proposals (One Per File)

<mandatory>Do NOT create RAG files directly in `docs/knowledge-base/`. Instead, create PROPOSALS in `docs/implementation/proposals/` that contain the RAG file content.</mandatory>

<guidance>
One proposal per file enables fine-grained extraction/exclusion by conductor. Allows rejection of individual files without affecting others.
</guidance>

**For [N] RAG files:** Create [N] separate proposal files:
- `docs/implementation/proposals/[task-id]-rag-{file-name-1}.md`
- `docs/implementation/proposals/[task-id]-rag-{file-name-2}.md`
- ... (one for each RAG file)

<template follow="format">
```markdown
---
type: rag-addition
task_id: [task-id]
created: YYYY-MM-DD
target_category: [category]
target_filename: [filename].md
---

# RAG Proposal: {Descriptive Title}

## Reasoning

[Why this belongs in KB. What pattern discovered, why future sessions would benefit.]

## RAG Match List (0.4 threshold)

| Existing File | Score | Relevance |
|---|---|---|
| [matching files, if any] | [score] | [relationship] |

[Or: "No existing entries matched at 0.4 threshold."]

## Proposed RAG File

Target path: `docs/knowledge-base/[category]/[filename]`

<!-- BEGIN RAG FILE -->
---
id: [kebab-case-id]
created: YYYY-MM-DD
category: [category]
parent_topic: [Logical Grouping]
tags: [tag1, tag2, tag3]
---

[Full RAG file content. Keep self-contained, include examples, no external refs.]

<!-- END RAG FILE -->
```
</template>

<guidance>
**Pre-screening (before creating each proposal):**
1. Query KB: `query_documents("[topic]", limit=10)` at 0.4 relevance threshold
2. If matches found (score < 0.3): Record in RAG Match List, consider updating existing file instead
3. If no matches (> 0.4): Proceed with new file proposal
</guidance>

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = '[task-id]';
```
</template>
</core>
</section>

<section id="review-checkpoint">
<mandatory>
## Review Checkpoint

All review checkpoint content is non-negotiable. Include one review checkpoint section per checkpoint specified in the header. Adapt the review focus and summary to the specific work being reviewed.
</mandatory>

<core>
### Step [N]: Request Review

**Commit work so far:**

<template follow="exact">
```bash
git add [specific files]

git commit -m "$(cat <<'EOF'
[task-id]: [checkpoint summary]

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
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'CHECKPOINT [N]: REVIEW REQUEST
Context Usage: [actual %]
Self-Correction: [YES/NO]
Deviations: [count + severity]
Agents Remaining: [N] ([description])
Proposal: [path or N/A]
Summary: [what was accomplished]
Files Modified: [count]
Tests: [status]
Smoothness: [0-9]
Reason: [why review needed]
Key Outputs:
  - [path] (created/modified/rag-addition)',
'review_request');

-- Then state
UPDATE orchestration_tasks
SET state = 'needs_review',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>

<context>
**Review message fields (all 11 required):**
- `Context Usage: [actual %]` — Your current context usage
- `Self-Correction: [YES/NO]` — Whether you self-corrected during this phase
- `Deviations: [count + severity]` — Issues encountered
- `Agents Remaining: [count] ([description])` — Remaining background agents and description
- `Proposal: [path]` — Path to extraction analysis proposal
- `Summary: [what was found]` — Key results description
- `Files Modified: [count]` — Number of files changed
- `Tests: [status]` — Test results or "N/A" for doc-only tasks
- `Smoothness: [0-9]` — Quality/confidence score (see smoothness scale in SKILL.md)
- `Reason: [why review needed]` — Why this checkpoint requires conductor review
- `Key Outputs: [paths]` — Files created, modified, or added to RAG
</context>

### Step [N+1]: Wait for Review

**Terminate background subagent:**
```python
TaskStop(task_id=[subagent-id])
```

**Launch BLOCKING subagent to wait for review:**

<template follow="exact">
```python
Task(
    description="Wait for review approval for [task-id]",
    prompt="""Wait for conductor review of [task-id].

Poll every 10 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = '[task-id]'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = '[task-id]' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

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
WHERE task_id = '[task-id]';
```
</template>

<mandatory>Relaunch background monitoring subagent (same as Step 2) after every review checkpoint.</mandatory>
</core>
</section>

<section id="post-review-execution">
<core>
## Post-Review Execution

<guidance>
Steps that occur after conductor approval. Same format as Work Execution.
</guidance>

### Step [N+2]: [Post-review action]

[Detailed instructions for remaining work]
</core>
</section>

<section id="verification">
<core>
## Verification Checklist

- [ ] [Check description]
      **Verify:** `[command]`
      **Expected:** [output]
      **If failed:** [remediation]

- [ ] [Continue for all checks]

<mandatory>All checks must pass before proceeding to completion.</mandatory>

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = '[task-id]';
```
</template>
</core>
</section>

<section id="testing">
<core>
## Testing Requirements

### Unit Tests (if applicable)

**File:** `[test file path]`

**Tests to write:**
1. Test [behavior] - [expected outcome]

### Manual Verification

- [ ] [Manual check]
</core>
</section>

<section id="completion">
<mandatory>
## Completion

All completion steps are non-negotiable.
</mandatory>

<core>
### Step [N]: Commit Changes

<template follow="exact">
```bash
git add [specific files]

git commit -m "$(cat <<'EOF'
[task-id]: [summary]

[details]

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```
</template>

### Step [N+1]: Terminate Background Subagent

```python
TaskStop(task_id=[subagent-id])
```

### Step [N+2]: Generate Completion Report

**Save to:** `[report path]`

<template follow="format">
```markdown
# Task [ID] Completion Report

**Date:** YYYY-MM-DD
**Status:** Complete
**Token usage:** ~[actual]k tokens (estimated: [XX]k)

---

## Summary

[What was accomplished]

---

## Verification Results

[All checks with PASS/FAIL]

---

## Review Checkpoint

**Smoothness score:** [0-9]
**Review outcome:** Approved
**Feedback:** [conductor feedback]

---

## Files Created/Modified

**Created:**
- [list]

**Modified:**
- [list]

---

## Issues Encountered

[Problems and resolutions, or "None"]

---

## Commit

**SHA:** [hash]
**Files:** [count] added/modified
```
</template>

### Step [N+3]: Update Database (TERMINAL WRITE)

<mandatory>Message FIRST, then state + metadata. This is the last database write — the report must already exist at `[report path]` before this step.</mandatory>

<template follow="exact">
```sql
-- Message FIRST
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'TASK COMPLETE: [summary]

Smoothness: [0-9]
Context Usage: [X]%
Self-Correction: [YES/NO]
Deviations: [count]
Files Modified: [count]
Tests: [status]
Key Outputs:
  - [path] (created/modified/rag-addition)

Report: [report path]
Commit: [SHA]
All verification checks: PASSED',
'completion');

-- Then state + metadata
UPDATE orchestration_tasks
SET state = 'complete',
    completed_at = datetime('now'),
    report_path = '[report path]',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>
</core>
</section>

<section id="deliverables">
<core>
## Deliverables

### Code (REQUIRED)
- [ ] [All specified files created/modified]
- [ ] [All tests passing]

### Reports (REQUIRED)
- [ ] Completion report at [report path]

### Proposals (REQUIRED when applicable)
- [ ] RAG proposal: [required/not applicable] - [what to document]
- [ ] Database proposal: [required/not applicable]
- [ ] API proposal: [required/not applicable]
</core>
</section>

<section id="success-criteria">
<core>
## Success Criteria

- [ ] [All task-specific success criteria from objective]
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
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'ERROR (Retry [N]/5): [description]

Context Usage: [X]%
Self-Correction: [YES/NO]
Step: [which step failed]
Error: [specific message]
Context: [relevant state]
Report: [error report path]
Key Outputs:
  - [path] (created/modified)
Proposed fix: [what will be tried]
Awaiting conductor fix proposal',
'error');

UPDATE orchestration_tasks
SET state = 'error',
    retry_count = retry_count + 1,
    last_error = '[error summary]',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
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
WHERE task_id = '[task-id]';
-- Session will terminate via hook exit criteria
```
</template>
</core>
</section>

<section id="reference">
<core>
## Reference

**Implementation plan:** [path] (Section: [relevant section])
**Design document:** [path] (Section: [relevant section])
</core>
</section>

</task-instruction>
```
</template>
</core>
</section>

</skill>
