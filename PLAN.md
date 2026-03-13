# AutoJe — Autonomous Research & Improvement for Ajentik Products

## What is AutoJe?

A fork of [karpathy/autoresearch](https://github.com/karpathy/autoresearch) adapted for Ajentik's product repos. The original lets an AI agent autonomously experiment with LLM training code in a tight loop: modify → run → evaluate → keep/discard → repeat. We take this exact pattern and apply it to **our own products**.

Instead of optimizing `val_bpb` on a training script, AutoJe optimizes **real product metrics** — test pass rate, bundle size, response time, accessibility score, type coverage, security findings — across our core repos.

## Core Concept

```
Original autoresearch:          AutoJe:
┌─────────────┐                 ┌─────────────────┐
│ train.py    │  ←  agent       │ src/**          │  ←  agent
│ (one file)  │  modifies       │ (scoped module) │  modifies
├─────────────┤                 ├─────────────────┤
│ val_bpb     │  ←  metric      │ test pass rate  │  ←  metric
│ (lower=     │  to beat        │ bundle size     │  to beat
│  better)    │                 │ lighthouse      │
│             │                 │ type coverage   │
├─────────────┤                 ├─────────────────┤
│ program.md  │  ←  human       │ program.md      │  ←  human
│ (research   │  writes         │ (improvement    │  writes
│  strategy)  │                 │  strategy)      │
└─────────────┘                 └─────────────────┘
```

The **three-file simplicity** carries over:
- `program.md` → human-written strategy (what to improve, constraints, scope)
- `evaluate.sh` → fixed metric collection script (replaces `prepare.py`)
- `target repo` → the code the agent modifies (replaces `train.py`)

## Target Repos & Metrics

### Phase 1: Quick Wins (measurable, automatable)

| Repo | Metric | Target | Evaluation |
|------|--------|--------|------------|
| **ajentik/axl** | `pnpm typecheck` error count | 0 errors | `pnpm typecheck 2>&1 \| grep -c error` |
| **ajentik/axl** | `pnpm lint` warning count | 0 warnings | `pnpm lint 2>&1 \| grep -c warning` |
| **ajentik/sct** | `pytest` pass rate | 100% | `pytest --tb=no -q \| tail -1` |
| **ajentik/sct** | `mypy --strict` error count | 0 errors | `mypy --strict \| grep -c error` |
| **ajentik/cga-elderwise** | Lighthouse perf score | >90 | `npx lighthouse --output=json` |
| **ajentik/wac-dashboard** | Bundle size (KB) | minimize | `pnpm build \| grep "total size"` |

### Phase 2: Product Quality

| Repo | Metric | Target | Evaluation |
|------|--------|--------|------------|
| **ajentik/elderwise-flutter** | `flutter test` pass count | maximize | `flutter test --reporter=json` |
| **ajentik/employer-wac** | `flutter analyze` issue count | 0 issues | `flutter analyze --no-fatal-infos` |
| **ajentik/helper-wac** | `flutter analyze` issue count | 0 issues | `flutter analyze --no-fatal-infos` |
| **ajentik/core** | `rspec` pass rate | 100% | `bundle exec rspec --format progress` |

### Phase 3: Advanced (multi-metric)

| Repo | Metrics | Evaluation |
|------|---------|------------|
| **ajentik/ajentik-svelte** | Lighthouse (perf + a11y + SEO) | Composite score |
| **ajentik/yanok-svelte** | Lighthouse + bundle size | Weighted composite |
| **ajentik/elderwise-svelte** | Lighthouse + a11y + i18n coverage | Weighted composite |

## Architecture

```
autoje/
├── programs/               # One program.md per repo/metric combo
│   ├── axl-typecheck.md
│   ├── sct-pytest.md
│   ├── elderwise-flutter-analyze.md
│   ├── cga-lighthouse.md
│   └── ...
├── evaluators/             # Fixed evaluation scripts (do not modify)
│   ├── flutter-analyze.sh
│   ├── node-typecheck.sh
│   ├── python-pytest.sh
│   ├── lighthouse.sh
│   └── bundle-size.sh
├── runners/                # Orchestration
│   ├── run-single.sh       # Run one experiment loop
│   ├── run-swarm.sh        # Launch parallel loops across repos
│   └── monitor.sh          # Track progress across all experiments
├── results/                # TSV logs per repo (gitignored)
│   └── *.tsv
├── PLAN.md                 # This file
└── README.md               # Updated from upstream
```

## How It Works

### Single Experiment Loop (same as autoresearch)

```
1. Agent reads program.md for the target repo
2. Agent reads current codebase state
3. Agent makes a targeted modification
4. Run evaluator (fixed time/scope budget)
5. Compare metric to baseline
6. If improved → git commit (keep)
   If worse → git reset (discard)
7. Log result to results.tsv
8. GOTO 3 (never stop)
```

### Key Differences from Original

| Aspect | autoresearch | AutoJe |
|--------|-------------|--------|
| Target | Single file (train.py) | Scoped module/directory |
| Metric | val_bpb (single float) | Test pass %, lint count, bundle size, etc. |
| Time budget | 5 min (GPU training) | 1-5 min (build + test + eval) |
| Hardware | GPU required | CPU only (CI-like) |
| Scope | One repo | Multi-repo swarm |
| Agent | Any coding agent | opencode agents in tmux |

### Scoping Rules (prevent runaway changes)

Each `program.md` defines:
- **Allowed files**: glob pattern of files the agent can touch
- **Forbidden files**: files that must not change (like `prepare.py` in original)
- **Metric threshold**: minimum improvement to keep a change (e.g., must reduce errors by ≥1)
- **Complexity budget**: max lines changed per experiment (e.g., 50 lines)
- **Revert on regression**: any metric that gets worse → automatic revert

## Swarm Mode

Run AutoJe across all repos simultaneously:

```bash
# Launch improvement swarms for all Phase 1 repos
./runners/run-swarm.sh \
  --repos axl,sct,cga-elderwise,wac-dashboard \
  --agent opencode \
  --max-experiments 50 \
  --parallel 4
```

Each repo gets its own:
- tmux session
- git branch (`autoje/<date>-<metric>`)
- results.tsv
- Isolated worktree (no conflicts between agents)

## Integration with Existing Swarm Infrastructure

AutoJe plugs directly into our existing `swarm-launcher.sh`:

1. **Before swarm**: Run AutoJe to improve test pass rates, reduce lint errors
2. **During swarm**: Issue-fix agents work on the improved codebase
3. **After swarm**: Run AutoJe again to optimize what the agents produced

Think of it as **continuous autonomous improvement** between human sprints.

## Example: program.md for ajentik/axl

```markdown
# AutoJe: axl TypeScript Quality

## Goal
Reduce TypeScript type errors and ESLint warnings to zero.

## Metric
Combined score = (typecheck_errors * 10) + eslint_warnings
Lower is better. Target: 0.

## Evaluation (do not modify)
Run: `./evaluators/node-typecheck.sh /path/to/axl`

## Scope
- ALLOWED: `src/**/*.ts`, `src/**/*.svelte`
- FORBIDDEN: `tests/**`, `package.json`, `svelte.config.js`, `vite.config.ts`
- MAX LINES CHANGED: 30 per experiment

## Strategy
1. Start with the lowest-hanging fruit (missing type annotations)
2. Fix one file per experiment — keep changes small and reviewable
3. Prefer adding types over suppressing errors
4. Never add `// @ts-ignore` or `any` — that's cheating
5. If stuck, try a different file
```

## Rollout Plan

### Week 1: Proof of Concept
- [ ] Adapt autoresearch structure for Node.js/Flutter evaluation
- [ ] Write evaluators for typecheck, lint, test pass rate
- [ ] Write 2-3 program.md files (axl-typecheck, sct-pytest)
- [ ] Run overnight on axl — target: zero typecheck errors by morning

### Week 2: Multi-Repo
- [ ] Add Flutter evaluators (analyze, test)
- [ ] Add Lighthouse evaluator
- [ ] Run swarm across 4 repos simultaneously
- [ ] Build monitoring dashboard (results.tsv → simple web view)

### Week 3: Production Integration
- [ ] Auto-create PRs from improvement branches
- [ ] Add CI gate: AutoJe results must not regress
- [ ] Cron schedule: run AutoJe nightly on all repos
- [ ] Add Slack/Telegram notifications for improvements

### Week 4: Advanced
- [ ] Multi-metric composite scoring
- [ ] Agent learns from past experiments (feed results.tsv as context)
- [ ] Cross-repo optimizations (shared components)
- [ ] A/B test different program.md strategies

## Why This Will Work for Ajentik

1. **We already have the swarm infrastructure** — tmux sessions, worktrees, opencode agents
2. **Our repos have measurable quality gaps** — 744 debug prints, 70+ force-unwraps, failing CI, low test coverage
3. **Fixed time budget per experiment** — prevents runaway agent behavior
4. **Git-based keep/discard** — every change is reviewable, no magic
5. **Scales horizontally** — run 10 repos × 100 experiments overnight = 1000 improvements while sleeping
6. **Karpathy's insight applies**: you're not writing code, you're **programming the program.md** — the meta-strategy that guides autonomous improvement

## The Vision

> "You wake up in the morning to a log of experiments and (hopefully) a better codebase."

Every night, AutoJe agents run across all Ajentik repos. Each morning, the team reviews a results.tsv showing what improved. The best changes get merged. Over time, the program.md files themselves evolve to find the fastest path to better products.

This is autoresearch for product engineering.
