# Copyist-Musician Alignment Review — Complete

*Source: Merged findings from two independent reviews, 2026-02-24*
*Status: All items resolved*

## Applied Fixes (this session)

### Copyist template/schema fixes
- **Guard clause** — `NOT IN` → `IN ('watching', 'fix_proposed', 'exit_requested')` in 3 locations
- **Background poll interval** — 8s → 15s in parallel template + schema reference
- **Blocking poll interval** — 8s → 10s in parallel template + schema reference + example
- **Blocking review timeout** — 150 iterations (20min) → 90 iterations (15min) in all locations
- **Handoff threshold** — 70% → 65% in parallel template, added to sequential template
- **Heartbeat refresh** — Added 3rd poll-cycle job to background subagent templates
- **Error report fields** — Enriched to 9 fields (added Context Usage, Self-Correction, Report, Key Outputs) across all SQL locations + SKILL.md
- **Completion report fields** — Enriched (Smoothness, Context Usage, Self-Correction, Deviations, Files Modified, Tests, Key Outputs) across all SQL locations + SKILL.md
- **Review request fields** — Added `Key Outputs` as 11th field, updated all "10 fields" → "11 fields"
- **`model="opus"`** — Added to both subagent templates in schema reference and parallel template
- **Anti-patterns** — Added #24 (overly permissive guard clauses) and #25 (polling interval drift)
- **Sequential error recovery** — Added mandatory blocking subagent for waiting on fix proposals
- **Completion ordering** — Reordered parallel template: Commit → Report → DB update (terminal state last)
- **Parallel example RAG workflow** — Replaced `ingest_file` step with proposal-based workflow; updated Step 7 (RAG files → RAG proposals), Step 9 (ingestion → proposal verification), verification checklist, commit, and completion message

### Conductor alignment fixes
- **Error report format** — Conductor's reference updated to match Copyist's enriched format
- **Review request format** — Unified to Copyist's layout + Key Outputs (11 fields)
- **Launch prompt field** — "Line range" → "Phase section"
- **Danger file report fields** — Aligned between Conductor and Copyist

### Musician fix
- **Vocabulary table** — Added `danger-files` row to `task-instruction-processing` section
