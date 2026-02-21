<skill name="copyist-schema-reference" version="2.0">

<metadata>
type: reference
parent-skill: copyist
tier: 3
</metadata>

<sections>
- database
- state-machine
- sql-patterns
- subagent-templates
- hook-system
</sections>

<section id="database">
<core>
## Database

**Path:** comms.db (project root)
**Access:** comms-link MCP (sessions) + sqlite3 (stop hook)
</core>

<context>
WAL isolation: comms-link cannot see changes made by external sqlite3 and vice versa.
Use comms-link for all orchestration DB operations within sessions.
</context>

<core>
### orchestration_tasks

<template follow="exact">
```sql
CREATE TABLE orchestration_tasks (
    task_id TEXT PRIMARY KEY,
    state TEXT NOT NULL CHECK (state IN (
        'watching', 'reviewing', 'exit_requested', 'complete',
        'working', 'needs_review', 'review_approved', 'review_failed',
        'error', 'fix_proposed', 'exited'
    )),
    instruction_path TEXT,
    session_id TEXT,
    worked_by TEXT,
    started_at TEXT,
    completed_at TEXT,
    report_path TEXT,
    retry_count INTEGER DEFAULT 0,
    last_heartbeat TEXT,
    last_error TEXT
);
```
</template>

<mandatory>CREATE TABLE with CHECK constraints must use `comms-link execute` (raw SQL), NOT `create-table` tool.</mandatory>

### orchestration_messages

<template follow="exact">
```sql
CREATE TABLE orchestration_messages (
    id INTEGER PRIMARY KEY,
    task_id TEXT NOT NULL,
    from_session TEXT NOT NULL,
    message TEXT NOT NULL,
    message_type TEXT CHECK (message_type IN (
        'review_request', 'error', 'context_warning', 'completion',
        'emergency', 'handoff', 'approval', 'fix_proposal',
        'rejection', 'instruction', 'claim_blocked', 'resumption'
    )),
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP
);
```
</template>

<mandatory>All INSERTs into orchestration_messages must specify message_type. No NULL message_type values.</mandatory>
</core>
</section>

<section id="state-machine">
<core>
## State Machine

### Conductor States (task-00)

| State | Set By | Meaning |
|-------|--------|---------|
| `watching` | Conductor | Monitoring musician tasks |
| `reviewing` | Conductor | Actively reviewing a task's work |
| `exit_requested` | Conductor | Ready to exit, cleanup complete |
| `complete` | Conductor | All work finished |

### Musician States (task-01+)

| State | Set By | Meaning |
|-------|--------|---------|
| `working` | Musician | Actively performing task |
| `needs_review` | Musician | Work ready for conductor review |
| `review_approved` | Conductor | Review passed, musician may continue |
| `review_failed` | Conductor | Review failed, feedback provided |
| `error` | Musician | Error encountered, awaiting fix proposal |
| `fix_proposed` | Conductor | Fix instructions sent to musician |
| `complete` | Musician | Task finished successfully |
| `exited` | Both | Session terminated (conductor: staleness detection; musician: 5th retry failure) |
</core>

<context>
### Initial State

The Conductor creates task rows before launching musicians. The initial state is not constrained by the CHECK — rows are inserted with whatever state the Conductor chooses (typically a state NOT IN the musician claim exclusion list: `'working', 'complete', 'exited'`). The claim SQL's `AND state NOT IN (...)` clause serves as the effective guard.
</context>

<mandatory>
### Heartbeat Rule

Every SQL UPDATE that changes `state` MUST also set `last_heartbeat = datetime('now')`.

Include standalone heartbeat updates after major steps even without state changes.
</mandatory>

<mandatory>
### Message Type Rule

Every INSERT into orchestration_messages MUST specify a `message_type` value.
Valid values: `review_request`, `error`, `context_warning`, `completion`, `emergency`, `handoff`, `approval`, `fix_proposal`, `rejection`, `instruction`, `claim_blocked`, `resumption`.
</mandatory>
</section>

<section id="sql-patterns">
<core>
## SQL Patterns

### Initialization (Musician Session)

<template follow="exact">
```sql
-- Atomic claim
UPDATE orchestration_tasks
SET state = 'working',
    session_id = '$CLAUDE_SESSION_ID',
    worked_by = '$CLAUDE_SESSION_ID',
    started_at = datetime('now'),
    last_heartbeat = datetime('now'),
    retry_count = 0
WHERE task_id = '[task-id]'
  AND state NOT IN ('working', 'complete', 'exited');
```
</template>

### Heartbeat Update

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>

### Request Review

<mandatory>Message FIRST, then state change. All 10 review fields required.</mandatory>

<template follow="exact">
```sql
-- Message FIRST, then state change
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'REVIEW REQUEST: [summary]

Context Usage: [X]%
Self-Correction: [YES/NO]
Deviations: [count + severity]
Agents Remaining: [N] ([description])
Proposal: [path or N/A]
Summary: [what was accomplished]
Files Modified: [count]
Tests: [status or N/A]
Smoothness: [0-9]
Reason: [why review needed]

Review focus:
- [what to check]

Commits: [SHA]',
'review_request');

UPDATE orchestration_tasks
SET state = 'needs_review',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>

### After Approval (Resume Working)

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'working',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
```
</template>

### Report Error

<template follow="exact">
```sql
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
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
WHERE task_id = '[task-id]';
```
</template>

### Mark Complete

<mandatory>Message FIRST, then state + metadata.</mandatory>

<template follow="exact">
```sql
-- Message FIRST
INSERT INTO orchestration_messages (task_id, from_session, message, message_type)
VALUES ('[task-id]', '$CLAUDE_SESSION_ID',
'TASK COMPLETE: [summary]

[details]

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

### Terminal Failure (5th retry)

<template follow="exact">
```sql
UPDATE orchestration_tasks
SET state = 'exited',
    last_heartbeat = datetime('now')
WHERE task_id = '[task-id]';
-- Session will terminate via hook exit criteria
```
</template>

### Check for Conductor Messages

<template follow="exact">
```sql
SELECT message, timestamp
FROM orchestration_messages
WHERE task_id = '[task-id]'
  AND from_session = 'task-00'
ORDER BY timestamp DESC
LIMIT 1;
```
</template>

### Check Task State

<template follow="exact">
```sql
SELECT state, retry_count, last_heartbeat
FROM orchestration_tasks
WHERE task_id = '[task-id]';
```
</template>
</core>
</section>

<section id="subagent-templates">
<core>
## Background Monitoring Subagent Template

<template follow="exact">
```python
Task(
    description="Monitor conductor messages for [task-id]",
    prompt="""Monitor coordination database for [task-id].

Check every 8 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = '[task-id]'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = '[task-id]' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

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

## Blocking Review Subagent Template

<template follow="exact">
```python
Task(
    description="Wait for review approval for [task-id]",
    prompt="""Wait for conductor review of [task-id].

Poll every 8 seconds using comms-link:
1. Query: SELECT state FROM orchestration_tasks WHERE task_id = '[task-id]'
2. Query: SELECT message FROM orchestration_messages WHERE task_id = '[task-id]' AND from_session = 'task-00' ORDER BY timestamp DESC LIMIT 1

Exit when state changes from 'needs_review' to:
- 'review_approved' -> Report: APPROVED with feedback
- 'review_failed' -> Report: FAILED with feedback
- 'fix_proposed' -> Report: FIX PROPOSED with instructions

Include latest conductor message in response.

Max iterations: 150 (20 minutes)
If timeout: Report TIMEOUT""",
    subagent_type="general-purpose",
    run_in_background=False
)
```
</template>
</core>
</section>

<section id="hook-system">
<core>
## Hook System (Automatic)
</core>

<context>
The stop hook activates automatically when a session's `CLAUDE_SESSION_ID` is found in `orchestration_tasks.session_id`. No manual setup script is needed — the task claim SQL (which writes `session_id`) is what activates the hook.
</context>

<core>
### Exit Criteria
- **Conductor (task-00):** `["exit_requested", "complete"]` (see `tools/implementation-hook/preset-conductor.yaml`)
- **Musician (task-01+):** `["complete", "exited"]` (see `tools/implementation-hook/preset-musician.yaml`)
</core>
</section>

</skill>
