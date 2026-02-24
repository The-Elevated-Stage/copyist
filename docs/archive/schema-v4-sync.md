# Copyist Schema — v4.0 Sync Complete

*Extracted from: review_copyist.md (2026-02-20 integration review)*
*Date: 2026-02-24*
*Status: All items resolved*

## Applied Changes

### States
- Added `context_recovery` and `confirmed` to `orchestration_tasks` CHECK constraint

### Message Types
- Added `system` to `orchestration_messages` CHECK constraint
- Added `system` to Message Type Rule valid values list

### Tables
- Added `repetiteur_conversation` table DDL (sender, message, timestamp)
- Added context explaining sender values (`conductor`, `repetiteur`, `user`)

### Initial Data
- Added `souffleur` + `task-00` INSERT examples in new "Initial Data" context block
- Documented insertion ordering (souffleur BEFORE task-00)

### State Machine Documentation
- Added `context_recovery` to Conductor States table
- Added new "Infrastructure States (souffleur row)" subsection with `watching` and `confirmed`

### Exit Criteria
- Updated Conductor exit criteria: `["exit_requested", "complete", "context_recovery"]`
- Fixed preset file reference: `preset-conductor.yaml` -> `preset-orchestration.yaml`

### Consistency Fixes
- Updated Initial State context paragraph: old `NOT IN` guard clause language -> current `IN (...)` pattern
- Version bump: `2.0` -> `4.0`
