# AutoJe: SCT Frontend Quality Improvement

## Goal
Fix failing tests, implement pending/skipped tests, and eliminate any type errors in the SCT frontend.

## Current Baseline (2026-03-13)
- vitest: 8980 passed, 2 failed, 15 pending out of 8997 total
- svelte-check: 0 errors, 0 warnings
- **composite_score: 2150** (2 failed × 1000 + 15 pending × 10)

## Metric
`composite_score` from `evaluators/sct-frontend.sh` — lower is better. Target: 0.

## Evaluation (do not modify)
Run: `bash /Users/a1/.openclaw/workspace/autoje/evaluators/sct-frontend.sh /Users/a1/.openclaw/workspace/sct`

## Scope
- **ALLOWED**: `frontend/src/**/*.ts`, `frontend/src/**/*.svelte`, `frontend/src/tests/**`
- **FORBIDDEN**: `frontend/package.json`, `frontend/svelte.config.js`, `frontend/vite.config.ts`, `frontend/vitest.config.ts`, `frontend/tsconfig.json`, `frontend/e2e/**`, `backend/**`
- **MAX LINES CHANGED**: 80 per experiment (keep changes small, focused, reviewable)

## Strategy

### Priority 1: Fix the 2 failing tests
These are the highest-weighted items (1000 points each). Read the test failure output carefully:
```
npx vitest run --reporter=verbose 2>&1 | grep -A 10 "FAIL"
```
- Understand WHY each test fails — is it a test bug or a code bug?
- If the test expectation is wrong, fix the test
- If the code is wrong, fix the code
- Run evaluator after EACH fix

### Priority 2: Implement the 15 pending/skipped tests
Each pending test is worth 10 points. They exist as skeletons — fill them in:
```
grep -rn "it.skip\|test.skip\|xit\|xtest\|it.todo\|test.todo" frontend/src/tests/
```
- Implement one pending test per experiment
- If a pending test can't be implemented (needs infrastructure), convert it to a proper TODO with explanation
- Some may be skipped for good reason — read the surrounding context

### Priority 3: Type safety improvements
If svelte-check shows warnings or errors, fix them:
- Add missing type annotations
- Fix type mismatches
- Never use `// @ts-ignore` or `any` — that's cheating

### Anti-patterns (do NOT do these)
- Do NOT delete tests to reduce failure count
- Do NOT mark failing tests as `.skip` or `.todo`
- Do NOT add `// @ts-expect-error` to suppress type errors
- Do NOT modify the evaluator script
- Do NOT modify config files (vitest.config, tsconfig, etc.)
- Do NOT install new dependencies

### Experiment discipline
- ONE change per experiment (one test fix OR one test implementation)
- Run evaluator after every change
- If score improves → git commit and keep
- If score stays same or worsens → git reset and try different approach
- Keep a mental model of diminishing returns — move to next priority when stuck
