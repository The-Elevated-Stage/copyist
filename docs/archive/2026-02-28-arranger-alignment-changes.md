# Copyist — Changes Needed for Arranger Alignment

**Date:** 2026-02-28
**Source:** `stagecraft/docs/working/2026-02-28-arranger-design-action-plan.md`
**Purpose:** Document all changes needed to the Copyist skill so that a separate session can execute them.

---

## Context

The Arranger-Copyist alignment review (2026-02-28) found **strong architectural alignment** — sentinel markers, plan-index, line-range extraction, self-containment philosophy, and dual-audience document structure all match well. The critical issues found are internal Copyist example bugs rather than structural misalignments with the Arranger.

Key alignment points that are already working and should NOT be changed:
- Sentinel marker parsing and line-range-based reading
- Self-containment enforcement ("copy all relevant plan content into the instruction")
- The 7 expected phase section components (Objective, Prerequisites, Implementation detail, Integration points, Frontend guidelines, Expected outcomes, Testing recommendations) — identical between Arranger and Copyist
- Launch prompt template — all fields are populated from Arranger output + Conductor decisions
- Context budget model (140k file reads + 30k output) — supported by plan-index selective loading
- Tier transformation: Copyist correctly transforms Tier 2 phase content into Tier 3 task instructions

---

## Changes Required

### 1. Authority Tag Consumption — Document Input Signal

**Current state:** Copyist SKILL.md (lines 92-99) lists expected phase components but does not document how to interpret authority tags (`<mandatory>`, `<guidance>`, `<core>`) within the Arranger's phase section content. The Copyist uses authority tags for output (task instructions) but has no documented rule for consuming them from input.

**Required change:** Add a note to SKILL.md's workflow section (around line 76, after the "Expected phase components" list):

The Arranger's phase sections use authority tags to classify content:
- `<mandatory>` content from the phase section should be preserved verbatim in task instructions. These represent non-negotiable constraints that the Conductor cannot override and Musicians must follow exactly.
- `<guidance>` content can be adapted for task-level context. These are the Arranger's recommendations.
- `<core>` is primary implementation content — the substance to be decomposed into task steps.

This creates a consumption contract: the Arranger uses authority tags strategically knowing that `<mandatory>` content will be preserved verbatim in task instructions.

### 2. `<section>` Tag Awareness

**Current state:** Copyist's phase parsing documentation (SKILL.md lines 79-103) only references sentinel markers and markdown headers. The `<section id="phase-N">` tags that the Arranger places inside phase boundaries are not mentioned.

**Required change:** Add a brief note to the "Plan Structure" context block in SKILL.md:

Phase sections may contain `<section id="phase-N">` tags per the Tier 2 hybrid document convention. These coexist with sentinel markers and can be safely ignored — the Copyist works from the full phase text bounded by sentinel markers. The `<section>` tags provide structural validation but are not needed for content extraction.

### 3. Integration Surface Handling Guidance

**Current state:** The Copyist expects "Integration points" as a phase section component (SKILL.md line 97) but has no explicit template section or guidance for where to place integration surface information in task instructions.

**Required change:** Add guidance to SKILL.md's workflow section:

Arranger phase sections contain an "Integration Points" subsection describing how the phase's work connects to other phases. Distribute this information across task instruction sections:
- **Prerequisites** — dependency contracts (what this task needs from prior phases)
- **Danger Files** — shared resource coordination (files modified by multiple tasks)
- **Work Execution steps** — implementation-level integration (interfaces to implement, contracts to maintain)

### 4. Example Bug Fixes

These are internal Copyist bugs surfaced during the review. They do not affect the Arranger design but directly affect task instruction quality.

#### 4.1 Guard Clause in Both Examples

**Current (wrong):** Both `sequential-task-example.md` (line 118) and `parallel-task-example.md` (line 141) use:
```sql
AND state NOT IN ('working', 'complete', 'exited')
```

**Required (correct):** Match the templates, schema reference, and anti-pattern #24:
```sql
AND state IN ('watching', 'fix_proposed', 'exit_requested')
```

The `NOT IN` pattern is overly permissive and could allow claiming tasks in unsafe states. Anti-pattern #24 (`anti-patterns.md` lines 456-466) explicitly flags this as wrong.

#### 4.2 Background Subagent Polling Interval

**Current (wrong):** `parallel-task-example.md` (line 165) uses 8-second polling interval.

**Required (correct):** Use 15-second polling interval, matching the templates (`parallel-task-template.md` line 195), schema reference (`schema-and-coordination.md` line 361), and anti-pattern #25 (`anti-patterns.md` lines 469-480).

#### 4.3 Background Subagent Heartbeat Maintenance

**Current (missing):** `parallel-task-example.md` background subagent template (lines 158-180) omits the heartbeat maintenance logic.

**Required:** Add step 3 of the monitoring loop — checking `last_heartbeat` and updating if older than 60 seconds. Match the canonical pattern in `schema-and-coordination.md` (lines 358-381) and `parallel-task-template.md` (lines 189-215).

Without heartbeat maintenance, the Conductor's staleness detection may incorrectly flag active Musicians as stale.

#### 4.4 Error Report Missing Fields

**Current (incomplete):** `parallel-task-example.md` error report SQL (lines 775-793) omits several canonical fields.

**Required:** Add missing fields to match the canonical error report pattern in `schema-and-coordination.md` (lines 254-278): `Context Usage`, `Self-Correction`, `Report`, and `Key Outputs`.

---

## Validation

After changes are made, verify:
- [ ] Authority tag consumption is documented in SKILL.md with clear rules for `<mandatory>`, `<guidance>`, `<core>`
- [ ] `<section>` tag presence is acknowledged in the Plan Structure context block
- [ ] Integration surface handling guidance is present in the workflow section
- [ ] Both examples use `IN ('watching', 'fix_proposed', 'exit_requested')` guard clause
- [ ] Parallel example uses 15-second polling interval
- [ ] Parallel example background subagent includes heartbeat maintenance
- [ ] Parallel example error report includes all canonical fields
- [ ] Run `copyist/skill/scripts/validate-instruction.sh` against the updated examples to confirm they pass
