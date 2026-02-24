#!/usr/bin/env bash
# validate-instruction.sh — Check a task instruction file for common issues
# Usage: bash validate-instruction.sh <path-to-instruction.md>

set -uo pipefail

FILE="${1:?Usage: validate-instruction.sh <path-to-instruction.md>}"

if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File not found: $FILE"
    exit 1
fi

ERRORS=0
WARNINGS=0

error() { echo "  ERROR: $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo "  WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }
ok()    { echo "  OK:    $1"; }

echo "=== Validating: $FILE ==="
echo ""

# --- Detect task type ---
IS_PARALLEL=false
if grep -qi "Parallel-safe.*Yes\|parallel-safe.*true" "$FILE" 2>/dev/null; then
    IS_PARALLEL=true
fi

# --- Tier 3 Format Checks ---
echo "--- Tier 3 Format Checks ---"

# Check for task-instruction wrapper
if grep -q "<task-instruction" "$FILE" 2>/dev/null; then
    ok "Has <task-instruction> wrapper"
    # Check for id and type attributes
    if grep -qP '<task-instruction\s+id="[^"]*"\s+type="[^"]*"' "$FILE" 2>/dev/null; then
        ok "task-instruction has id and type attributes"
    else
        error "task-instruction missing id or type attribute"
    fi
else
    warn "No <task-instruction> wrapper found (may be an example file containing one)"
fi

# Check for metadata tag
if grep -q "<metadata>" "$FILE" 2>/dev/null; then
    ok "Has <metadata> tag"
else
    warn "No <metadata> tag found"
fi

# Check for sections index
if grep -q "<sections>" "$FILE" 2>/dev/null; then
    ok "Has <sections> index"
else
    warn "No <sections> index found"
fi

# Check for mandatory-rules section
if grep -q 'id="mandatory-rules"' "$FILE" 2>/dev/null; then
    ok "Has mandatory-rules section"
else
    warn "No mandatory-rules section found"
fi

# Check for mandatory tags
if grep -q "<mandatory>" "$FILE" 2>/dev/null; then
    ok "Has <mandatory> tags"
else
    error "No <mandatory> tags found — task instructions must have mandatory rules"
fi

# TODO: Add naked-markdown detection — verify no text exists inside <section> tags
# without being wrapped in <core>, <mandatory>, <guidance>, or <context>.
# This is the central Tier 3 requirement (hybrid-doc-structure.md, Guideline 7).
# Non-trivial to implement in bash due to tag nesting parsing.

# --- Legacy Marker Checks ---
echo ""
echo "--- Legacy Marker Checks ---"

# Check for [STRICT]/[FLEXIBLE] used as section markers (should use <mandatory>/<core> instead)
# Only flag when used as section markers (e.g., "## Section [STRICT]"), not in explanatory text
if grep -qP '^#+\s.*\[STRICT\]' "$FILE" 2>/dev/null; then
    error "Found [STRICT] section marker — use <mandatory> tag instead"
fi
if grep -qP '^#+\s.*\[FLEXIBLE\]' "$FILE" 2>/dev/null; then
    error "Found [FLEXIBLE] section marker — use <core> or <guidance> tag instead"
fi

# --- Required Sections (All Tasks) ---
echo ""
echo "--- Required Sections (All Tasks) ---"

for section in "Objective" "Prerequisites" "Initialization" "Work Execution" "Verification" "Testing Requirements" "Completion" "Deliverables" "Error Recovery" "Reference"; do
    if grep -qi "## $section" "$FILE" 2>/dev/null; then
        ok "Section found: $section"
    else
        error "Missing section: $section"
    fi
done

# Check header fields (either in metadata tag or markdown header)
for field in "token-estimate\|Token estimate" "review-checkpoints\|Review checkpoints" "parallel-safe\|Parallel-safe" "dependencies\|Dependencies"; do
    if grep -qi "$field" "$FILE" 2>/dev/null; then
        ok "Header field: $(echo "$field" | sed 's/\\|/ or /g')"
    else
        error "Missing header field: $(echo "$field" | sed 's/\\|/ or /g')"
    fi
done

# Check for Critical success criteria in Objective
if grep -qi "Critical [Ss]uccess [Cc]riteria" "$FILE" 2>/dev/null; then
    ok "Critical success criteria present"
else
    error "Objective missing Critical success criteria"
fi

# --- Parallel Task Sections ---
if $IS_PARALLEL; then
    echo ""
    echo "--- Parallel Task Sections ---"

    for section in "Danger Files" "Review Checkpoint" "Post-Review Execution" "Success Criteria"; do
        if grep -qi "## $section" "$FILE" 2>/dev/null; then
            ok "Section found: $section"
        else
            error "Parallel task missing section: $section"
        fi
    done

    if grep -qi "Hook\|hook.*activat\|stop.hook\|exit.criteria\|preset-execution\|preset-musician" "$FILE" 2>/dev/null; then
        ok "Hook system referenced"
    else
        error "Parallel task missing hook system reference"
    fi

    if grep -qi "Background.*[Ss]ubagent\|run_in_background.*True" "$FILE" 2>/dev/null; then
        ok "Background subagent referenced"
    else
        error "Parallel task missing background subagent"
    fi

    if grep -qi "review_approved\|review_failed\|BLOCKING\|run_in_background.*False" "$FILE" 2>/dev/null; then
        ok "Blocking review wait referenced"
    else
        error "Parallel task missing blocking review wait"
    fi

    if grep -qi "Smoothness" "$FILE" 2>/dev/null; then
        ok "Smoothness score referenced"
    else
        error "Parallel task missing smoothness score in review messages"
    fi
fi

# --- Schema Checks ---
echo ""
echo "--- Schema Checks ---"

# Old table names
if grep -q "migration_tasks" "$FILE" 2>/dev/null; then
    error "Old table name found: migration_tasks (use orchestration_tasks)"
fi
if grep -q "coordination_status" "$FILE" 2>/dev/null; then
    error "Old table name found: coordination_status (use orchestration_tasks)"
fi
if grep -q "task_messages" "$FILE" 2>/dev/null; then
    # Check it's not in a comment or description
    if grep -v "renamed from\|old.*task_messages\|was task_messages" "$FILE" | grep -q "task_messages" 2>/dev/null; then
        error "Old table name found: task_messages (use orchestration_messages)"
    fi
fi

# Status column
if grep -qP "SET\s+status\s*=" "$FILE" 2>/dev/null; then
    error "Old column reference: SET status = ... (use state, not status)"
fi
if grep -qP "SELECT\s+status\s" "$FILE" 2>/dev/null; then
    error "Old column reference: SELECT status (use state, not status)"
fi

# Valid table names present
if grep -q "orchestration_tasks" "$FILE" 2>/dev/null; then
    ok "Uses orchestration_tasks"
else
    warn "No reference to orchestration_tasks found"
fi
if grep -q "orchestration_messages" "$FILE" 2>/dev/null; then
    ok "Uses orchestration_messages"
else
    warn "No reference to orchestration_messages found"
fi

# --- message_type Column Check ---
echo ""
echo "--- message_type Column Check ---"

# Count INSERT INTO orchestration_messages statements
INSERT_COUNT=$(grep -c "INSERT INTO orchestration_messages" "$FILE" 2>/dev/null) || true
MSGTYPE_COUNT=$(grep -c "message_type" "$FILE" 2>/dev/null) || true

if [[ "$INSERT_COUNT" -gt 0 ]]; then
    # Check that INSERTs include message_type in the column list
    INSERTS_WITHOUT_TYPE=$(grep -P "INSERT INTO orchestration_messages\s*\(" "$FILE" 2>/dev/null | grep -cv "message_type" || true)
    if [[ "$INSERTS_WITHOUT_TYPE" -gt 0 ]]; then
        error "Found $INSERTS_WITHOUT_TYPE INSERT(s) into orchestration_messages without message_type column"
    else
        ok "All orchestration_messages INSERTs include message_type"
    fi
else
    ok "No orchestration_messages INSERTs to check (or all in template blocks)"
fi

# --- Session ID Check ---
echo ""
echo "--- Session ID Check ---"

# Check for old [session-id] placeholder (should use $CLAUDE_SESSION_ID)
if grep -qP "\[session-id\]" "$FILE" 2>/dev/null; then
    error "Found [session-id] placeholder — use \$CLAUDE_SESSION_ID instead"
else
    ok "No [session-id] placeholders found"
fi

if grep -q 'CLAUDE_SESSION_ID' "$FILE" 2>/dev/null; then
    ok "Uses \$CLAUDE_SESSION_ID"
fi

# --- Heartbeat Checks ---
echo ""
echo "--- Heartbeat Checks ---"

# Count state changes vs heartbeat updates
STATE_CHANGES=$(grep -cP "SET\s+state\s*=" "$FILE" 2>/dev/null) || true
HEARTBEAT_UPDATES=$(grep -c "last_heartbeat" "$FILE" 2>/dev/null) || true

if [[ "$STATE_CHANGES" -gt 0 && "$HEARTBEAT_UPDATES" -lt "$STATE_CHANGES" ]]; then
    error "Found $STATE_CHANGES state changes but only $HEARTBEAT_UPDATES heartbeat references (should be >= state changes)"
else
    ok "Heartbeat coverage: $HEARTBEAT_UPDATES references for $STATE_CHANGES state changes"
fi

# --- Placeholder Checks ---
echo ""
echo "--- Placeholder Checks ---"

# Unfilled template placeholders (but allow runtime placeholders)
RUNTIME_PLACEHOLDERS="task-id|git SHA|SHA|actual|YYYY-MM-DD|subagent-id|your-session-id|your-id|dependency-id|report path|error summary|file-path|STRICT|FLEXIBLE"
BAD_PLACEHOLDERS=$(grep -oP '\[(?!'"$RUNTIME_PLACEHOLDERS"')[A-Z][A-Z _-]+\]' "$FILE" 2>/dev/null | sort -u || true)

if [[ -n "$BAD_PLACEHOLDERS" ]]; then
    warn "Possible unfilled placeholders found:"
    echo "$BAD_PLACEHOLDERS" | while read -r p; do
        echo "    $p"
    done
else
    ok "No suspicious unfilled placeholders"
fi

# TODO/FIXME markers
if grep -qi "TODO\|FIXME\|XXX\|HACK" "$FILE" 2>/dev/null; then
    warn "Found TODO/FIXME markers — ensure these are intentional"
fi

# TEMPLATE NOTE markers (should be removed)
if grep -q "TEMPLATE NOTE:" "$FILE" 2>/dev/null; then
    error "Template notes still present (TEMPLATE NOTE: markers should be removed)"
fi

# --- Self-Containment Check ---
echo ""
echo "--- Self-Containment Check ---"

if grep -qiP "see (the )?(implementation |design )?plan\b|refer to .*(plan|doc)" "$FILE" 2>/dev/null; then
    warn "Possible external reference found — verify instruction is self-contained"
fi

# Check for reference section (acceptable external references)
if grep -qi "## Reference" "$FILE" 2>/dev/null; then
    ok "Reference section present (external refs acceptable here)"
fi

# --- Temp Directory Check ---
echo ""
echo "--- Temp Directory Check ---"

if grep -P '(?<!\w)/tmp/' "$FILE" 2>/dev/null | grep -vqi "never.*use\|don't.*use\|do not.*use\|not.*/tmp/\|never.*\`/tmp/\`"; then
    error "Found /tmp/ reference — use temp/ (project root) instead"
else
    ok "No /tmp/ references (or only in 'never use' context)"
fi

# --- RAG Section Check ---
echo ""
echo "--- RAG Section Check ---"

if grep -qi "knowledge-base\|RAG\|rag-\|ingest" "$FILE" 2>/dev/null; then
    if grep -qi "## RAG Proposal Creation" "$FILE" 2>/dev/null; then
        ok "RAG Proposal Creation section present"
    else
        warn "File references RAG/knowledge-base but has no '## RAG Proposal Creation' section"
    fi
else
    ok "No RAG references found (section not required)"
fi

# --- Completion Report Check ---
echo ""
echo "--- Completion Report Check ---"

if grep -qi "completion report\|report.*path\|Save to:" "$FILE" 2>/dev/null; then
    ok "Completion report path referenced"
else
    error "Missing completion report path"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"

if [[ "$ERRORS" -gt 0 ]]; then
    echo "  Status:   FAIL — fix errors before returning to conductor"
    exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
    echo "  Status:   PASS with warnings — review before returning"
    exit 0
else
    echo "  Status:   PASS"
    exit 0
fi
