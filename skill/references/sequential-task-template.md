<skill name="copyist-sequential-template" version="2.0">

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

Specific SQL blocks and code patterns within any section are wrapped in `<template follow="exact">` — reproduce these verbatim with only placeholder values changed.
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
<task-instruction id="[task-id]" type="sequential">

<metadata>
parallel-safe: false
dependencies: [task IDs that must complete first, or "none"]
token-estimate: ~[XX]k
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
- Context budget: 140k tokens for file reads, 170k total session cap — prepare handoff at 65% usage
</mandatory>
</section>

<section id="objective">
<core>
## Objective

[1-3 sentences describing what this task accomplishes and why it matters]

### Critical Success Criteria
1. [Measurable outcome 1]
2. [Measurable outcome 2]
3. [Continue as needed]
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
WHERE task_id = '[task-id]'
  AND state IN ('watching', 'fix_proposed', 'exit_requested');
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

### Step 1: [Action Name]

**Context estimate:** ~[X]k tokens
- `[file-path]` — ~[N] lines ([full read / lines X-Y, section description])
**Running total:** ~[X]k / 140k

[Detailed instructions]

```[language]
[code example if applicable]
```

**Expected outcome:**
- [What success looks like]

**If issues arise:**
- [Troubleshooting guidance]

<template follow="exact">
```sql
UPDATE orchestration_tasks SET last_heartbeat = datetime('now') WHERE task_id = '[task-id]';
```
</template>

### Step 2: [Continue pattern]

[... continue for all steps]

<guidance>
Between major steps, check for conductor messages:
</guidance>

<template follow="exact">
```sql
-- Check for conductor messages (non-blocking)
SELECT message, timestamp FROM orchestration_messages
WHERE task_id = '[task-id]' AND from_session = 'task-00'
ORDER BY timestamp DESC LIMIT 1;
```
</template>
</core>
</section>

<section id="rag-proposals">
<context>
## RAG Proposal Creation

Include this section only when the task involves RAG/knowledge-base work. If not applicable, keep the heading and write "N/A — [reason]".
</context>

<core>
### Before Completion: Create RAG Proposals (One Per File)

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
</core>
</section>

<section id="testing">
<core>
## Testing Requirements

### Unit Tests (if applicable)

**File:** `[test file path]`

**Tests to write:**
1. Test [behavior] - [expected outcome]
2. Test [edge case] - [expected outcome]

### Manual Verification

- [ ] [Manual check 1]
- [ ] [Manual check 2]
</core>
</section>

<section id="completion">
<core>
## Completion

### Commit Changes

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

### Update Database

<mandatory>Message FIRST, then state change.</mandatory>

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

-- Then state
UPDATE orchestration_tasks
SET state = 'complete',
    completed_at = datetime('now'),
    report_path = '[report path]',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>

### Completion Report

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
</core>
</section>

<section id="deliverables">
<core>
## Deliverables

### Code (REQUIRED)
- [ ] All specified files created/modified
- [ ] All tests passing
- [ ] No lint warnings or errors

### Reports (REQUIRED)
- [ ] Completion report at specified path

### Proposals (REQUIRED when applicable)
- [ ] RAG proposal: [required/not applicable] - [what to document]
- [ ] Database proposal: [required/not applicable]
- [ ] API proposal: [required/not applicable]
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
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'ERROR (Retry [N]/5): [description]

Context Usage: [X]%
Self-Correction: [YES/NO]
Step: [which step]
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

<mandatory>After reporting an error, launch a blocking subagent to wait for the conductor's fix proposal. Do not proceed without it — the session has no other way to receive conductor instructions.</mandatory>

<template follow="exact">
```python
Task(
    description="Wait for fix proposal for [task-id]",
    prompt="""Wait for conductor fix proposal for [task-id].

Poll every 10 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = '[task-id]'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = '[task-id]' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

Exit when state changes from 'error' to:
- 'fix_proposed' -> Report: FIX PROPOSED with instructions

Include latest conductor message in response.

Max iterations: 90 (15 minutes)
If timeout: Report TIMEOUT""",
    subagent_type="general-purpose",
    model="opus",
    run_in_background=False
)
```
</template>

Apply the conductor's fix instructions, update state back to `working`, and retry the failed step.

<mandatory>If retry count reaches 5, session must exit.</mandatory>

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
