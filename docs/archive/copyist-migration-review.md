# Copyist Skill Migration Review

**Date:** 2026-02-18
**Reviewers:** Claude Opus (deep), Claude Haiku (quick-scan), Gemini Flash (architectural), Skill-Reviewer (format/quality)
**Target:** `skills_staged/copyist/` (9 files, 4,110 lines)
**Migration:** Pure markdown → Hybrid XML/Markdown (Tier 2/3)

---

## Executive Summary

All four reviewers gave a **PASS** verdict. The migration is solid with strong Tier 3 compliance, excellent progressive disclosure, and thorough SQL pattern consistency. Two critical issues were found (review field count inconsistency, missing naked-markdown validation), plus several moderate and minor findings. Gemini raised interesting architectural questions about whether SQL belongs in instructions at all.

**Findings by severity:**
- Critical: 2
- Moderate: 7
- Minor: 8
- Positive: 8+ (highlights only)

---

## Critical Issues

### C1. Review Message Field Count: 9 vs 10

**Source:** Opus deep review
**Location:** `references/parallel-task-template.md` lines 335, 342-352

The `<mandatory>` tag says "All 9 review message fields are required" but the `<template follow="exact">` block below it contains **10 fields** (includes `Reason:`). Cross-references:

| Source | Fields | Includes `Reason:`? | Includes `Proposal:`? |
|--------|--------|---------------------|----------------------|
| SKILL.md line 211 | 9 | No | Yes |
| Parallel template (exact block) | 10 | Yes | Yes |
| Parallel template (context block) | 9 | No | Yes |
| Schema-and-coordination.md | 9 | No | Yes |
| Parallel example | 9 | No | Yes |
| Hybrid-doc spec (line 653) | 9 | Yes | No |

Three-way inconsistency: SKILL.md has `Proposal` but no `Reason`, the spec has `Reason` but no `Proposal`, the template has both.

**Decision needed:** Is it 9 fields or 10? Which fields are canonical?

### C2. Validation Script Missing Naked-Markdown Check

**Source:** Opus deep review
**Location:** `scripts/validate-instruction.sh`

The script checks for `<task-instruction>` wrapper, `<metadata>`, `<sections>`, `<mandatory>` tags, and many SQL/content issues — but does NOT check for naked markdown (text inside `<section>` tags without being wrapped in `<core>`, `<mandatory>`, `<guidance>`, or `<context>`). This is the central Tier 3 requirement (hybrid-doc-structure.md, Guideline 7).

SKILL.md validation checklist (line 270) explicitly lists this check. Anti-patterns.md documents it as pattern #18. But the script doesn't enforce it.

**Decision needed:** Add naked-markdown detection to the script? (Non-trivial to implement in bash — may need to parse tag nesting.)

---

## Moderate Issues

### M1. Hybrid-Doc Spec Has SQL Errors (Not a Copyist Bug)

**Source:** Opus deep review
**Location:** `docs/hybrid-document-structure.md` lines 538, 653-654

The authoritative spec has errors the Copyist correctly fixes:
- Line 538: `AND state = 'pending'` — `pending` is not a valid state
- Line 653: Column `type` instead of `message_type`
- Line 654: Value `'status'` instead of `'review_request'`
- Missing `worked_by`, `started_at`, `retry_count = 0` in claim SQL

**Decision needed:** Fix the spec in a separate pass? The Copyist is correct; the spec is wrong.

### M2. Legacy `[STRICT]`/`[FLEXIBLE]` Explanation in Parallel Template

**Source:** Opus + Skill-reviewer
**Location:** `references/parallel-task-template.md` line 22

The usage `<mandatory>` block explains the old convention: "Sections that were previously marked `[STRICT]` contain content wrapped in `<mandatory>`..." The sequential template does NOT have this legacy explanation. This migration-era context could confuse future readers.

**Decision needed:** Remove the legacy explanation? The anti-patterns file (#21) already documents the migration path.

### M3. Missing `pending` State Documentation

**Source:** Opus deep review
**Location:** `references/schema-and-coordination.md` lines 37-41

The DDL CHECK constraint lists 11 valid states but there's no `pending` state. The initial state of newly-created task rows is undocumented in the Copyist. The claim SQL uses `NOT IN ('working', 'complete', 'exited')` which works but doesn't explain what state tasks start in.

**Decision needed:** Document the conductor's task creation convention?

### M4. Validation Script Placeholder Check Misses Lowercase

**Source:** Opus deep review
**Location:** `scripts/validate-instruction.sh` lines 244-255

The runtime placeholder allowlist regex `[A-Z][A-Z _-]+` only catches ALL-CAPS placeholders. Lowercase template placeholders like `[count]`, `[summary]`, `[description]`, `[status]`, `[what was accomplished]` that leak into generated files won't be flagged.

**Decision needed:** Extend the regex to catch lowercase placeholders? Or accept the heuristic?

### M5. No Clarification/Rejection Path for Ambiguous Plans

**Source:** Gemini architectural review

The Copyist has no mechanism to reject or request clarification on a poorly-defined plan section. If the Arranger produces vague input, the Copyist is forced to "hallucinate" details to satisfy the self-containment and mandatory-sections requirements.

**Decision needed:** Add a `<clarification-request>` output path? Or rely on the Conductor to vet plan quality before invoking the Copyist?

### M6. "Agents Remaining" Field Format Inconsistency

**Source:** Skill-reviewer
**Location:** SKILL.md line 211 vs `examples/parallel-task-example.md` line 345

SKILL.md specifies "count and %" format. The parallel example shows `Agents Remaining: 1 (background monitor)` — a count with description, not percentage.

**Decision needed:** Which format is canonical?

### M7. Prompt Precedence Rule Location

**Source:** Haiku quick-scan
**Location:** SKILL.md line 106

The prompt precedence rule (`<mandatory>The launch prompt's Overrides & Learnings take precedence...`) appears inside the workflow section. It's also in the mandatory-rules block (indirectly). Consider whether it should be more prominent at the top.

**Decision needed:** Duplicate as an explicit mandatory rule?

---

## Minor Issues

### m1. 22 Anti-Patterns May Be "Instruction Bloat"

**Source:** Gemini architectural review

Gemini argues most LLMs have an "attention cliff" and will focus on the first 5 and last 2 of 22 patterns. Suggestion: move Critical patterns into `<mandatory>` rules, embed Format patterns into the validation script, and keep only "nuance" patterns in the anti-patterns list.

**Note:** The anti-patterns file is `load="recommended"` — not always loaded. This partially mitigates the concern.

### m2. Context Estimation Gap

**Source:** Gemini architectural review

The Copyist estimates musician context usage but doesn't see the actual codebase files the musician will edit. It can only estimate based on plan descriptions, not verified file sizes. A "Resource Mapping" step to verify file existence before writing instructions could help.

### m3. SQL in Instructions vs. Musician's Own Skills

**Source:** Gemini architectural review

Gemini questions whether the Copyist should pre-write SQL at all. Alternative: define state transitions abstractly and let the musician generate SQL from its own schema knowledge. Counter-argument: pre-written SQL reduces musician errors and is a deliberate design choice for reliability.

### m4. `[N]` Placeholders in Examples

**Source:** Opus minor finding
**Location:** `examples/parallel-task-example.md` lines 237-238

The parallel example uses `[N]` in the RAG proposal section, making the "concrete example" feel less concrete. Could show actual numbers (e.g., "Writing 8 proposal files").

### m5. SKILL.md at 319 Lines — Tier 2 Boundary

**Source:** Opus + Skill-reviewer

At 319 lines, SKILL.md is slightly over the 300-line soft boundary for Tier 2. The spec explicitly classifies copyist as Tier 2, so this is fine, but future additions could push it further.

### m6. Validation Script Path References Deployed Location

**Source:** Skill-reviewer
**Location:** SKILL.md line 117

Script path is `~/.claude/skills/copyist/scripts/validate-instruction.sh` — the deployed path. Won't work if invoked from `skills_staged/`. This is intentional (skill knows its deployment target) but worth noting.

### m7. Missing Anti-Pattern: Forgetting to Terminate Background Subagent

**Source:** Opus minor finding

The parallel template correctly shows `TaskStop(task_id=[subagent-id])` before completion, but this isn't called out as an anti-pattern. Zombie monitoring processes are a known failure mode.

### m8. Sequential Template Has No Review Message Template

**Source:** Opus minor finding

Sequential tasks have `review-checkpoints: 0`, so no review checkpoint section. Correct, but if a sequential task ever needed a review checkpoint, there's no template to follow. Low risk.

---

## Architectural Feedback (Gemini)

These are higher-level observations about the system design, not bugs:

1. **The "meta-template" concept is elegant but high-risk.** LLMs may struggle with nested tag contexts (generating `<task-instruction>` while inside a `<skill>` document). Gemini suggests distinct delimiters for template placeholders (e.g., `[[TASK_OBJECTIVE]]`) to make the "fill-in" nature more explicit.

2. **The "N/A — [reason]" requirement may incentivize compliance over quality.** An AI agent under pressure might mark critical sections like "Error Recovery" as N/A just to pass structural validation.

3. **Automate validation in the Conductor.** Instead of the Copyist self-running the validation script (which LLMs might simulate), have the Conductor receive output, run the script, and send errors back for a fixup pass.

4. **Add `parent_plan_hash` or `line_range_source` to task-instruction metadata.** Enables traceability from a failed task back to the original plan section.

---

## Positive Observations (Selected)

1. **SQL pattern consistency is excellent.** Every SQL template across all 7 markdown files uses correct column names, includes `message_type`, includes `last_heartbeat`.

2. **`$CLAUDE_SESSION_ID` migration is complete.** Zero instances of `[session-id]` anywhere.

3. **Tier 3 compliance is perfect across all 7 Tier 3 files.** No naked markdown found by any reviewer.

4. **Progressive disclosure is exemplary.** SKILL.md is ~1,450 words; full skill knowledge spans ~10,000+ words across 8 content files. Load directives are well-calibrated (`required` vs `recommended`).

5. **Self-containment principle is reinforced at 4 layers.** Mandatory rules → anti-pattern #1 → validation script → examples.

6. **Meta-template nesting is handled cleanly.** Outer `<template follow="format">` wraps a code fence containing the inner XML structure, avoiding tag collision.

7. **The validation script catches real failure modes.** Old table names, missing heartbeats, missing message_type, naked /tmp/ paths, missing sections — all covered.

8. **Authority tag discipline is strong.** `<mandatory>` used sparingly for genuinely non-negotiable constraints. No dilution.

---

## Decision Matrix

| ID | Issue | Severity | Effort | Recommendation |
|----|-------|----------|--------|----------------|
| C1 | Review field count 9 vs 10 | Critical | Low | Decide canonical count, update all refs |
| C2 | No naked-markdown validation | Critical | High | Accept gap or implement basic check |
| M1 | Spec SQL errors | Moderate | Low | Fix spec separately |
| M2 | Legacy [STRICT]/[FLEXIBLE] text | Moderate | Low | Remove from parallel template |
| M3 | Missing pending state docs | Moderate | Low | Add note to schema reference |
| M4 | Placeholder regex misses lowercase | Moderate | Medium | Extend regex or accept heuristic |
| M5 | No clarification path | Moderate | Medium | Design decision — defer or add |
| M6 | Agents Remaining format | Moderate | Low | Pick one format, update example |
| M7 | Prompt precedence location | Moderate | Low | Add to mandatory-rules block |
| m1-m8 | Minor issues | Minor | Various | Fix during next edit pass |
