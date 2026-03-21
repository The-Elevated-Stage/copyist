# Arranger Review Impacts — Copyist

**Date:** 2026-03-17
**Source:** `arranger/docs/working/2026-03-17-arranger-review.md`

## Changes Affecting Copyist

### 1. Self-Containment Component Count (DD-2)
`repertoire/output-format.md` now standardizes on 7 components with item 8 merged into item 3 (Implementation detail). The Copyist's self-containment verification should match.

### 2. Journal-Conventions Phase Numbering (DD-3)
`repertoire/journal-conventions.md` Arranger checkpoint triggers have been updated from a 5-phase model to a 6-phase model.

### 3. Pending Alignment Fixes
The following items from `copyist/docs/working/2026-02-28-arranger-alignment-changes.md` remain unimplemented — this review does not address them:
- Authority tag consumption rules (most consequential — Copyist has no contract for how `<mandatory>` vs `<core>` vs `<guidance>` content from the plan should be treated in generated task instructions)
- `<section>` tag awareness
- Integration surface handling
- Example guard clause bug (4.1) — uses overly permissive `NOT IN` pattern
- Example polling interval (4.2) — 8s instead of 15s
- Example heartbeat maintenance (4.3) — omitted
- Example error report fields (4.4) — missing fields
