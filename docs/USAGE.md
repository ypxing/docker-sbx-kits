# Using Skills and Agents

This is the full reference for skills, agents, and the issue tracker. For repo setup see the [README](../README.md). For a visual team walkthrough see [WORKFLOW.md](WORKFLOW.md).

---

## TL;DR

After `sbx-run`, the full autonomous workflow is three steps:

```
Step 1 — Plan
  Create issue files in .scratch/*/issues/*.md
  (manually, or with planning skills — see Skills below)

Step 2 — Sprint (hands-off)
  > /afk-sprint           ← implements all ready issues in parallel, commits, reviews

Step 3 — Triage
  > /address-code-review  ← apply review findings with TDD
```

For a single issue hands-on: `/solve-issue ".scratch/.../issues/01-*.md"`

### Which platform?

| I want to…                   | Use                         |
| ---------------------------- | --------------------------- |
| Many issues (5+) in parallel | Claude Code (`/afk-sprint`) |
| Stay in my Copilot workspace | Copilot (`@afk-sprint`)     |
| Implement one issue manually | Either — `/solve-issue`     |

---

## Concepts

Three primitives make the system work:

### Skills

Reusable instructions that guide how the AI approaches a task. Invoked via `/slash-command` in chat.

- Live in `.claude/skills/<name>/SKILL.md`
- Shared across both Claude and Copilot sandboxes
- Do not spawn separate processes — they shape the current session's behaviour

**Bundled (included in this template):**

| Command                          | Purpose                                                                      |
| -------------------------------- | ---------------------------------------------------------------------------- |
| `/grill-me`                      | Stress-test a plan or design with relentless questions                       |
| `/grill-with-docs`               | Challenge a plan against your CONTEXT.md and ADRs                            |
| `/to-prd`                        | Formalise conversation context into a PRD file                               |
| `/to-issues`                     | Break a PRD into numbered issue files                                        |
| `/afk-sprint`                    | Autonomous sprint — implements all `ready-for-agent` issues hands-off        |
| `/solve-issue`                   | Implement one issue end-to-end: explore → TDD → verify → commit              |
| `/tdd`                           | TDD style guide — shapes failing-test-first approach for the current session |
| `/karpathy-guidelines`           | Apply LLM coding pitfall avoidance during writing/review                     |
| `/address-code-review`           | Triage local sprint review findings, implement valid ones with TDD           |
| `/address-pr-comments`           | Fetch external PR review comments, challenge each, implement valid ones      |
| `/improve-codebase-architecture` | Surface refactoring opportunities informed by your domain model              |

### Agents

Autonomous workers that operate independently. Their structure differs by platform:

- **Claude Code**: defined in `.claude/agents/` with YAML frontmatter specifying model, isolation mode, and available tools. Spawned by `/afk-sprint` via a workflow engine.
- **GitHub Copilot**: defined in `.github/agents/` as standalone `.agent.md` files. Invoked via `@agent-name` in chat.

### Issue Tracker

A markdown-based issue system in `.scratch/` — no external service needed. Both platforms read and write the same format. Issues have a `Status:` line that agents use to decide what to pick up. See [Issue Tracker Conventions](#issue-tracker-conventions) below.

---

## The Lifecycle

Every feature follows the same three phases regardless of platform:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   PLAN                 IMPLEMENT               REVIEW                       │
│                                                                             │
│   Create issue         ┌───────────┐           ┌───────────────┐            │
│   files manually  ─┐   │           │           │ code-reviewer │            │
│   (or with         │   │  AUTO:    │           └───────┬───────┘            │
│   optional         ├──►│  /afk-    │──────────────────►│                    │
│   planning         │   │  sprint   │                   ▼                    │
│   skills)         ─┘   │           │           ┌───────────────┐            │
│                        │  MANUAL:  │           │ /address-code │            │
│                        │  /solve-  │           │    -review    │            │
│                        │   issue   │           └───────────────┘            │
│                        └───────────┘                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Plan** — Create issue files that describe what to build. Use the bundled planning skills (`/grill-me`, `/to-prd`, `/to-issues`) or write them manually (see [Issue Tracker Conventions](#issue-tracker-conventions) for the format).

**Implement** — Either pick issues one by one with `/solve-issue`, or hand them all off to `/afk-sprint` (Claude) or `@afk-sprint` (Copilot) for autonomous implementation.

**Review** — The code reviewer agent flags security, quality, and correctness concerns. Triage findings with `/address-code-review` or handle external PR feedback with `/address-pr-comments` (if installed).

---

## Claude Code

### Prerequisites

- `sbx` CLI installed and authenticated
- AWS SSO session active: `aws sso login --profile sso-live`
- `spec.yaml` generated: `./setup.sh` (see [README](../README.md))

### Getting started

```bash
sbx-run claude-docker
```

You land in a Claude Code session with all bundled skills and agents preloaded. Type `/command-name` to invoke any skill.

### Autonomous sprint (`/afk-sprint`)

The fastest path from issues to merged code. You prepare the work, walk away, and come back to results.

**Step 1 — Prepare issues**

Create issue files in `.scratch/` and mark them `ready-for-agent`. Use `/to-prd` then `/to-issues` (bundled), or write the files manually:

```markdown
<!-- .scratch/rate-limiting/issues/01-token-bucket.md -->

Status: ready-for-agent

# Add token bucket rate limiter

## Context

We need per-client rate limiting at the API gateway layer.

## Acceptance criteria

- [ ] Token bucket with configurable rate and burst
- [ ] Middleware returning 429 when bucket empty
- [ ] Tests covering refill, burst, and exhaustion

## Blocked by

(none)
```

**Step 2 — Run the sprint**

```
> /afk-sprint
```

What happens behind the scenes:

```
/afk-sprint (orchestrator)
│
├── Scans .scratch/ for ready-for-agent issues
│   Skips issues whose "Blocked by" deps are not yet in done/
│
├── Spawns coder agents IN PARALLEL (batches of ~8)
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   │  coder           │  │  coder           │  │  coder           │
│   │  (worktree A)    │  │  (worktree B)    │  │  (worktree C)    │
│   │                  │  │                  │  │                  │
│   │  0. Pre-flight   │  │  0. Pre-flight   │  │  0. Pre-flight   │
│   │  1. Read issue   │  │  1. Read issue   │  │  1. Read issue   │
│   │  2. Explore code │  │  2. Explore code │  │  2. Explore code │
│   │  3. Install deps │  │  3. Install deps │  │  3. Install deps │
│   │  4. TDD loop     │  │  4. TDD loop     │  │  4. TDD loop     │
│   │  5. Verify checks│  │  5. Verify checks│  │  5. Verify checks│
│   │  6. Commit       │  │  6. Commit       │  │  6. Commit       │
│   └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
│            │                     │                     │
│            ▼                     ▼                     ▼
├── Merges all complete branches back to main (--no-ff)
│   Issues moved to done/ — partial/blocked issues get progress notes
│
├── code-reviewer agent runs AUTOMATICALLY
│   └── Report saved to .scratch/reviews/sprint-review-<timestamp>.md
│
└── Sprint summary printed to chat
```

Key properties:

- **Parallel**: multiple issues implemented simultaneously
- **Isolated**: each `coder` agent has its own git worktree (cannot interfere with others)
- **Self-verifying**: each agent runs tests and checks before reporting success

**Step 3 — Triage the review**

```
> /address-code-review
```

Claude reads the review findings, challenges weak ones, implements valid fixes with TDD, and commits.

### Manual feature development

For when you want to stay hands-on through each step:

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
│ create issues│   │ /solve-issue │   │ /solve-issue │   │ /address-pr-     │
│ manually (or │──►│ issue 01     │──►│ issue 02 ... │──►│ comments †       │
│ with optional│   │              │   │ (repeat)     │   │ handle PR review │
│ plan skills) │   │ explore→TDD  │   │              │   │ feedback         │
└──────────────┘   │ →verify→     │   └──────────────┘   └──────────────────┘
                   │  commit      │
                   └──────────────┘
```

† `/address-pr-comments` is bundled in this template.

```
> /solve-issue
> "Implement .scratch/rate-limiting/issues/01-token-bucket.md"
```

Reads the issue, explores the codebase, installs deps, runs a TDD loop, verifies all checks pass, and commits. Repeat per issue.

> **Tip:** `/tdd` is available as a style guide within any session — it shapes the failing-test-first approach but does not run the full issue loop on its own.

### Internals

| Component     | Location                                                        |
| ------------- | --------------------------------------------------------------- |
| Skills        | `.claude/skills/<name>/SKILL.md`                                |
| Agents        | `.claude/agents/{coder,code-reviewer}.md`                       |
| Isolation     | Each `coder` agent runs in a dedicated git worktree             |
| Orchestration | `/afk-sprint` skill drives a workflow engine that spawns agents |

---

## GitHub Copilot

### Prerequisites

- `sbx` CLI installed and authenticated
- GitHub token configured (injected automatically by the proxy)
- `spec.yaml` generated: `./setup.sh` (see [README](../README.md))

### Getting started

```bash
sbx-run copilot-sbx
```

You land in a Copilot chat session. Invoke agents with `@agent-name`.

### Autonomous sprint (`@afk-sprint`)

Same lifecycle as Claude, but with a different execution model.

**Step 1 — Prepare issues**

Identical to Claude — create issue files in `.scratch/` with `Status: ready-for-agent` and clear acceptance criteria. Same format, same labels.

**Step 2 — Run the sprint**

```
> @afk-sprint
```

What happens behind the scenes:

```
@afk-sprint (orchestrator)
│
├── Records HEAD SHA for code review scope
│
├── Scans .scratch/ for ready-for-agent issues
│   Respects "Blocked by" — skips issues whose deps aren't in done/
│
├── Dispatches issues SEQUENTIALLY to the coder subagent
│   ┌─────────────────────────────────────────────────────────┐
│   │                                                         │
│   │  Issue 01              Issue 02              Issue 03   │
│   │  ┌───────────┐        ┌───────────┐        ┌─────────┐  │
│   │  │ #coder    │──done─►│ #coder    │──done─►│ #coder  │  │
│   │  │ subagent  │        │ subagent  │        │subagent │  │
│   │  └───────────┘        └───────────┘        └─────────┘  │
│   │                                                         │
│   └─────────────────────────────────────────────────────────┘
│
├── @code-reviewer runs at end (mandatory — runs even if sprint stalls)
│
└── Stops if 2 consecutive rounds produce zero completions
```

Key differences from Claude:

- **Sequential**: one issue at a time (simpler but slower for large sprints)
- **No isolation**: each `coder` subagent works directly in the shared repo (a failure in issue N could affect issue N+1)
- **Subagent per issue**: `@afk-sprint` dispatches to `coder` for each issue, then does housekeeping itself

**Step 3 — Review**

The code reviewer runs automatically at protocol exit. You can also invoke it manually:

```
> @code-reviewer
```

Then triage findings:

```
> /address-code-review
```

### Using skills

The Copilot sandbox includes the same `.claude/skills/` directory. The bundled `/slash-commands` work in any Claude Code session opened inside the Copilot sandbox:

```
> /solve-issue ".scratch/.../issues/01-*.md"
> /address-code-review
> /tdd
```

### When to pick Copilot vs Claude

| Consideration                | Claude Code        | Copilot             |
| ---------------------------- | ------------------ | ------------------- |
| Many issues (5+)             | Faster (parallel)  | Slower (sequential) |
| Need isolation guarantees    | Worktree per issue | Shared repo         |
| Already in Copilot workspace | Switch context     | Stay in flow        |
| Few simple issues (1–3)      | Either works       | Either works        |
| Automatic code review        | Built-in           | Built-in            |

**Rule of thumb:** Use Claude for large sprints where parallelism matters. Use Copilot when you're already there and the workload is small.

### Internals

| Component       | Location                                                                  |
| --------------- | ------------------------------------------------------------------------- |
| Agents          | `.github/agents/{afk-sprint,coder,code-reviewer}.agent.md`                |
| Skills (shared) | `.claude/skills/<name>/SKILL.md`                                          |
| Isolation       | None — all agents work in the shared repo                                 |
| Orchestration   | `afk-sprint` agent dispatches each issue to `coder` subagent sequentially |

---

## Issue Tracker Conventions

Both platforms use the same markdown-based issue tracker. No external service required.

### Directory structure

```
.scratch/
└── <feature-slug>/
    ├── PRD.md                    # Product requirements
    └── issues/
        ├── 01-setup-schema.md    # Implementation issues (numbered for ordering)
        ├── 02-add-endpoint.md
        ├── 03-add-tests.md
        └── done/                 # Completed issues moved here by the agent
            └── 01-setup-schema.md
```

### Issue file format

```markdown
Status: ready-for-agent

# Short descriptive title

## Context

Why this issue exists and any relevant background.

## Acceptance criteria

- [ ] Specific, testable requirement
- [ ] Another requirement
- [ ] Edge case to handle

## Blocked by

- 01-setup-schema (or "none")
```

### Status labels

| Label             | Meaning                                                    |
| ----------------- | ---------------------------------------------------------- |
| `ready-for-agent` | Fully specified — agents will pick this up                 |
| `ready-for-human` | Needs human implementation (too ambiguous or risky for AI) |
| `needs-triage`    | Maintainer needs to evaluate scope and assignee            |
| `needs-info`      | Blocked on more information from reporter                  |
| `wontfix`         | Will not be addressed                                      |

### Tips for good issues

- One concern per issue — if you say "and also", split it
- Acceptance criteria should be testable (a test can verify each bullet)
- Use `## Blocked by` to declare dependencies — the agent respects these
- Keep context brief — link to the PRD for background rather than repeating it

---

## Quick Reference

| I want to…                    | Claude Code                      | Copilot                          |
| ----------------------------- | -------------------------------- | -------------------------------- |
| Stress-test a design †        | `/grill-me`                      | `/grill-me`                      |
| Create a PRD †                | `/to-prd`                        | `/to-prd`                        |
| Break PRD into issues †       | `/to-issues`                     | `/to-issues`                     |
| Run an autonomous sprint      | `/afk-sprint`                    | `@afk-sprint`                    |
| Implement one issue manually  | `/solve-issue`                   | `/solve-issue`                   |
| TDD style for current session | `/tdd`                           | `/tdd`                           |
| Review sprint output          | automatic                        | automatic (`@code-reviewer`)     |
| Triage code review            | `/address-code-review`           | `/address-code-review`           |
| Handle PR feedback †          | `/address-pr-comments`           | `/address-pr-comments`           |
| Improve architecture †        | `/improve-codebase-architecture` | `/improve-codebase-architecture` |

† Bundled in this template.

### Platform comparison

| Aspect               | Claude Code                                     | Copilot                    |
| -------------------- | ----------------------------------------------- | -------------------------- |
| Sprint execution     | Parallel (batches of ~8)                        | Sequential (one at a time) |
| Issue isolation      | Git worktree per `coder` agent                  | Shared repo                |
| Implement invocation | `/afk-sprint` (auto) or `/solve-issue` (manual) | `@afk-sprint` (auto)       |
| Code review trigger  | Automatic at sprint end                         | Automatic at protocol exit |
| Agent definitions    | `.claude/agents/`                               | `.github/agents/`          |
| Skill definitions    | `.claude/skills/` (shared)                      | `.claude/skills/` (shared) |
