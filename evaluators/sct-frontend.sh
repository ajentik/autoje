#!/bin/bash
# evaluate-sct-frontend.sh — FIXED EVALUATOR.
# Runs SCT frontend quality metrics and outputs composite score.
# Lower composite_score = better.

REPO_DIR="${1:-/Users/a1/.openclaw/workspace/sct}"
cd "$REPO_DIR/frontend"

# 1. Vitest — always capture output, ignore exit code (non-zero when tests fail)
TMPJSON=$(mktemp /tmp/vitest-autoje-XXXXXX.json)
npx vitest run --reporter=json >"$TMPJSON" 2>/dev/null; true

# Parse from file
vitest_failed=$(jq -r '.numFailedTests // 0' "$TMPJSON" 2>/dev/null)
vitest_passed=$(jq -r '.numPassedTests // 0' "$TMPJSON" 2>/dev/null)
vitest_total=$(jq -r '.numTotalTests // 0' "$TMPJSON" 2>/dev/null)
vitest_pending=$(jq -r '.numPendingTests // 0' "$TMPJSON" 2>/dev/null)
rm -f "$TMPJSON"

# 2. Svelte-check
svelte_output=$(npx svelte-check --tsconfig ./tsconfig.json 2>&1); true
svelte_errors=$(echo "$svelte_output" | grep -oE '[0-9]+ error' | head -1 | grep -oE '[0-9]+')
svelte_warnings=$(echo "$svelte_output" | grep -oE '[0-9]+ warning' | head -1 | grep -oE '[0-9]+')

# Sanitize
vitest_failed=$((${vitest_failed:-0} + 0))
vitest_passed=$((${vitest_passed:-0} + 0))
vitest_total=$((${vitest_total:-0} + 0))
vitest_pending=$((${vitest_pending:-0} + 0))
svelte_errors=$((${svelte_errors:-0} + 0))
svelte_warnings=$((${svelte_warnings:-0} + 0))

score=$(( vitest_failed * 1000 + vitest_pending * 10 + svelte_errors * 500 + svelte_warnings * 50 ))

echo "---"
echo "vitest_passed:      $vitest_passed"
echo "vitest_failed:      $vitest_failed"
echo "vitest_pending:     $vitest_pending"
echo "vitest_total:       $vitest_total"
echo "svelte_errors:      $svelte_errors"
echo "svelte_warnings:    $svelte_warnings"
echo "composite_score:    $score"
