# Copyist Skill — Integration Review Findings

*Source: Conductor skill review session, 2026-02-20*
*Reviewer: Copyist integration reviewer*

## Major (3)

### C-M1: Instructions boilerplate diverges from Conductor's version
- **Files:** `SKILL.md`, `references/launch-prompt-template.md` (lines 36-45)
- **Issue:** Copyist defines 8-step Instructions; Conductor's phase-execution.md defines 7-step. Different step content (Copyist has explicit "Read schema reference" step; Conductor omits it). Copyist's own `launch-prompt-template.md` line 51 says "The Instructions section is fixed boilerplate. The conductor does not modify it" — but the Conductor has its own divergent version.
- **Fix:** Designate the Copyist's version as canonical. The Conductor should import it verbatim rather than maintaining a separate copy.

### C-M2: No template support for danger file embedding
- **Files:** `references/parallel-task-template.md`, `references/sequential-task-template.md`
- **Issue:** Neither template has a designated location for danger file information. The Conductor's danger file governance (3-step flow) hands off to the Copyist via Overrides & Learnings, expecting the Copyist to embed coordination logic into task instructions. But the Copyist must improvise placement. The DANGER FILE UPDATE message template also has no template support.
- **Fix:** Add a `danger-files` subsection to the parallel task template (after `mandatory-rules`, before `objective`). Include placeholders for: danger file paths, shared task IDs, mitigation strategy, and the DANGER FILE UPDATE message template.

### C-M3: Hardcoded validation script path
- **File:** `SKILL.md` (line 145)
- **Issue:** Path `~/.claude/skills/copyist/scripts/validate-instruction.sh` is hardcoded. If the skill is staged or deployed elsewhere, validation silently fails.
- **Fix:** Use a path relative to the skill's deployment location, or add a comment noting the deployment dependency.

## Minor (3)

### C-m1: Says "subagent" where Conductor mandates "teammate"
- **Files:** `SKILL.md` (line 39), `references/launch-prompt-template.md` (line 122)
- **Issue:** Conductor mandates teammate spawning (>40k tokens). Copyist says "subagent" generically.
- **Fix:** Change to "teammate" to match Conductor's invocation pattern.

### C-m2: Error report format mismatch
- **Files:** `references/sequential-task-template.md` (lines 427-447), `references/parallel-task-template.md` (lines 652-672)
- **Issue:** Copyist templates include Step/Error/Context/Proposed-fix fields. Conductor expects Context-Usage%/Self-Correction/Report-path fields. Different field sets reduce diagnostic quality.
- **Fix:** Merge both field sets into a single canonical error report format.

### C-m3: Schema NOT NULL constraint divergence
- **File:** `references/schema-and-coordination.md` (lines 63-65)
- **Issue:** Copyist's schema reference has `NOT NULL` on task_id, from_session, message columns. Conductor's actual DDL (which runs during init) does not. Aspirational constraints not enforced.
- **Fix:** Either add NOT NULL to Conductor's DDL (safer) or remove from Copyist's reference to match reality.
