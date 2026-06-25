# Team Workflow Guide

This guide explains how development teams use the sbx sandbox to ship features with AI agents. Start here. See [USAGE.md](USAGE.md) for deeper reference on individual commands.

---

## Overview

The sandbox gives your team a three-phase AI-assisted delivery loop:

```
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                                                                          │
 │   IDEA                                                                   │
 │    │                                                                     │
 │    ▼                                                                     │
 │  ┌────────────────────────────────────────────────────────────────────┐  │
 │  │  PLAN  (you)                                                       │  │
 │  │                                                                    │  │
 │  │  Create .scratch/*/issues/*.md                                     │  │
 │  │  (manually, or with optional /grill-me /to-prd /to-issues †)       │  │
 │  └───────────────────────────┬────────────────────────────────────────┘  │
 │                              │                                           │
 │                              ▼                                           │
 │  ┌────────────────────────────────────────────────────────────────────┐  │
 │  │  IMPLEMENT  (agents)                                               │  │
 │  │                                                                    │  │
 │  │  /afk-sprint  ◄── walk away; parallel coder agents per issue       │  │
 │  │  Each issue → isolated worktree → TDD → verify → commit → merge    │  │
 │  └───────────────────────────┬────────────────────────────────────────┘  │
 │                              │                                           │
 │                              ▼                                           │
 │  ┌────────────────────────────────────────────────────────────────────┐  │
 │  │  REVIEW  (AI then you)                                             │  │
 │  │                                                                    │  │
 │  │  code-reviewer runs automatically ◄── CRITICAL/HIGH/MEDIUM/LOW     │  │
 │  │  /address-code-review  ◄── you triage findings and apply fixes     │  │
 │  └───────────────────────────┬────────────────────────────────────────┘  │
 │                              │                                           │
 │                              ▼                                           │
 │         CODE READY  (review, merge, deploy per your team process)        │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘
```

† `/grill-me`, `/to-prd`, `/to-issues` are bundled in this template.

---

# Part 1 — One-time setup

> Do this once per developer. After this, jump straight to [Part 2 — Day-to-day workflow](#part-2--day-to-day-workflow) for every feature.

## Prerequisites

Before starting, make sure you have:

- **`sbx` CLI** installed and authenticated (ask your platform team for the install link)
- **AWS SSO access** — your account needs an IAM role with Bedrock permissions (Claude template only)

## Step 1 — Install and configure credentials

```bash
# Install (or update) — clones to ~/.sbx-kits and symlinks sbx onto your PATH
curl -fsSL https://raw.githubusercontent.com/ypxing/docker-sbx-kits/main/install.sh | bash
```

Open `~/.sbx-kits/.env` and fill in your org's values:

```
SSO_SUBDOMAIN=your-org-sso        # e.g. "acme" → acme.awsapps.com
SSO_REGION=ap-southeast-2
SSO_ROLE_NAME=YourIAMRole
SSO_ACCOUNT_ID=123456789012
```

Then generate all `spec.yaml` files:

```bash
~/.sbx-kits/setup.sh
```

`setup.sh` runs `envsubst` over every `spec.src.yaml` under `agents/` and `kits/`, substituting your SSO values to produce the corresponding `spec.yaml` files (which are git-ignored).

> **Note:** Never edit `spec.yaml` directly — re-running `setup.sh` overwrites it. Edit `spec.src.yaml` instead.

## Step 2 — Choose your platform

Pick once based on your toolchain. This determines which `sbx-run` command you use every day.

```
 Do you use GitHub Copilot or Claude Code?
 │
 ├── Claude Code  ──►  sbx-run claude-sbx
 │                     Parallel coder agents, git worktree isolation per issue
 │
 └── Copilot      ──►  sbx-run copilot-sbx
                       Sequential coder subagent, simpler setup
```

Once the sandbox starts you are in a live chat session with the agent. All bundled skills and agents are pre-loaded.

See [Platform comparison](#platform-comparison) if you're unsure which to pick.

---

# Part 2 — Day-to-day workflow

> Before every session: run `aws sso login --profile sso-live` if your SSO token has expired, then `sbx-run <platform>`.

## Step 3 — Plan your feature

Create issue files that describe what to build. Each issue file is a plain markdown file in `.scratch/`.

**Using planning skills** (`/grill-me`, `/to-prd`, `/to-issues`):

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  > /grill-me       Agent asks hard questions about your design          │
│    "I want to      until every edge case is covered.                    │
│     add rate       (e.g. "What happens when tokens refill mid-burst?") │
│     limiting"                                                           │
│                                                                         │
│  > /to-prd         Formalises the conversation as a PRD at             │
│                    .scratch/rate-limiting/PRD.md                        │
│                                                                         │
│  > /to-issues      Breaks the PRD into numbered issue files at         │
│                    .scratch/rate-limiting/issues/                       │
│                      01-token-bucket.md    ← Status: ready-for-agent   │
│                      02-middleware.md                                   │
│                      03-integration-tests.md                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Without planning skills — write issue files manually:**

Create `.scratch/<feature-slug>/issues/<NN>-<slug>.md` directly:

```markdown
Status: ready-for-agent

# Add token bucket rate limiter

## Context

We need per-client rate limiting at the API gateway layer.

## Acceptance criteria

- [ ] Token bucket with configurable rate and burst
- [ ] Middleware returns 429 when bucket is empty
- [ ] Tests covering refill, burst, and exhaustion

## Blocked by

(none)
```

> **Key rule:** an issue is picked up by the agent only when its `Status` line is exactly `ready-for-agent`. Set it to `ready-for-human` for issues you want to implement yourself.

---

## Step 4 — Run the sprint

### Claude Code

```
> /afk-sprint
```

```
/afk-sprint (skill → workflow engine)
│
├─ Phase: List
│   └─ Scans .scratch/*/issues/*.md for "Status: ready-for-agent"
│       Skips issues whose "Blocked by" deps are not yet in done/
│
├─ Phase: Sprint  ← parallel, up to 8 issues at a time
│   │
│   ├── worktree-A           ├── worktree-B           ├── worktree-C
│   │   ┌───────────────┐    │   ┌───────────────┐    │   ┌───────────────┐
│   │   │ coder agent   │    │   │ coder agent   │    │   │ coder agent   │
│   │   │ issue 01      │    │   │ issue 02      │    │   │ issue 03      │
│   │   │               │    │   │               │    │   │               │
│   │   │ 0. pre-flight │    │   │ 0. pre-flight │    │   │ 0. pre-flight │
│   │   │ 1. read issue │    │   │ 1. read issue │    │   │ 1. read issue │
│   │   │ 2. explore    │    │   │ 2. explore    │    │   │ 2. explore    │
│   │   │ 3. deps       │    │   │ 3. deps       │    │   │ 3. deps       │
│   │   │ 4. TDD loop   │    │   │ 4. TDD loop   │    │   │ 4. TDD loop   │
│   │   │ 5. verify     │    │   │ 5. verify     │    │   │ 5. verify     │
│   │   │ 6. commit     │    │   │ 6. commit     │    │   │ 6. commit     │
│   │   └──────┬────────┘    │   └──────┬────────┘    │   └──────┬────────┘
│   │       complete         │       complete         │       blocked
│   │
├─ Phase: Merge
│   └─ git merge --no-ff per complete branch
│       Issues moved to done/  —  partial/blocked get progress notes
│
├─ Phase: Review  (automatic)
│   └─ code-reviewer agent reads every merged diff
│       Flags CRITICAL / HIGH / MEDIUM / LOW
│       Report saved to .scratch/reviews/sprint-review-<timestamp>.md
│
└─ Sprint summary printed to chat
```

Each `coder` agent runs in an **isolated git worktree** — they cannot interfere with each other.

### Copilot

```
> @afk-sprint
```

```
@afk-sprint (agent — runs the loop itself)
│
├─ Records HEAD SHA for review scope
│
├─ Scans .scratch/*/issues/*.md for "Status: ready-for-agent"
│   Respects "Blocked by" — skips until deps are in done/
│
├─ Issues processed SEQUENTIALLY  ← one at a time, shared repo
│
│   Issue 01           Issue 02           Issue 03
│   ┌───────────┐      ┌───────────┐      ┌───────────┐
│   │  #coder   │─done►│  #coder   │─done►│  #coder   │─► ...
│   │ subagent  │      │ subagent  │      │ subagent  │
│   └───────────┘      └───────────┘      └───────────┘
│
├─ @code-reviewer runs at end (mandatory — even if sprint stalled)
│
└─ Stops after 2 consecutive rounds with zero completions
```

No worktree isolation — all subagents write to the shared repo. A failure in one issue can affect the next.

### Issue status after the sprint

```
Before sprint:                    After sprint:

issues/                           issues/
├── 01-token-bucket.md            ├── 02-middleware.md   ← partial: retry next round
│   Status: ready-for-agent       │   ## Progress: ...
├── 02-middleware.md               └── done/
│   Status: ready-for-agent           └── 01-token-bucket.md
└── 03-tests.md                           Status: done
    Status: ready-for-agent
    Blocked by: 01-token-bucket
    (picked up next round once 01 lands in done/)
```

Blocked issues are automatically re-evaluated each round as their dependencies complete.

---

## Step 5 — Triage the review

The code-reviewer runs automatically at sprint end. After it finishes:

```
> /address-code-review
```

```
┌──────────────────────────────────────────────────────────────────────────┐
│  /address-code-review                                                    │
│                                                                          │
│  1. Reads .scratch/reviews/sprint-review-<latest>.md                     │
│                                                                          │
│  2. For each finding:                                                    │
│     ┌────────────────────────────────────────────────────┐               │
│     │  [HIGH] Missing input validation                   │               │
│     │  File: src/middleware/rate-limit.ts:42             │               │
│     │  Issue: userID from header not sanitised           │               │
│     │  Fix: add zod schema validation at entry point     │               │
│     └──────────────────────┬─────────────────────────────┘               │
│                            │                                             │
│               ┌────────────┴────────────┐                                │
│               │                         │                                │
│         Defensible?               Not defensible?                        │
│         (real issue)              (noise / wrong context)                │
│               │                         │                                │
│               ▼                         ▼                                │
│         Implement with TDD          Skip with note                       │
│         Commit the fix                                                   │
│                                                                          │
│  3. Summary: N implemented, N skipped, reasons for each                  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Manual path (stay hands-on)

When you prefer to implement issues yourself, one at a time.

`/solve-issue` runs the same logic as the `coder` agent (read issue → explore codebase → install deps → TDD loop → verify checks → commit) but in your current session, so you stay in the loop at every step.

```
  create issues          write issue files manually (or with optional
  (see Step 3)           planning skills if installed)
       │
       ▼
  /solve-issue           implement one issue end-to-end in your session
  ".scratch/.../
   issues/01-*.md"
       │
  (repeat per issue)
       │
       ▼
  push PR
       │
       ▼
  /address-pr-comments   fetch PR review comments, challenge each,
  (if installed)         implement valid ones with TDD, commit
```

> **`/tdd` vs `/solve-issue`:** `/tdd` is a style guide that shapes how the AI writes tests in the current session. `/solve-issue` runs the full single-issue loop including explore, deps, TDD, verify, and commit. Use `/solve-issue` when you want to hand off a complete issue; use `/tdd` to influence approach during any coding session.

---

## Issue file lifecycle

```
  Write manually                ┌─────────────────┐
  (or via optional  ──────────► │  needs-triage   │  Not yet reviewed by a human
  /to-issues skill)             └────────┬────────┘
                                         │  Human sets Status: ready-for-agent
                                         ▼
                                ┌─────────────────┐
  OR: write directly  ────────► │ ready-for-agent │  Agent will pick this up
  with this status              └────────┬────────┘
                               /afk-sprint or /solve-issue
                                 ┌───────┴────────┐
                                 │                │
                                 ▼                ▼
                      ┌──────────────┐   ┌───────────────────┐
                      │   complete   │   │ partial / blocked │
                      └──────┬───────┘   └────────┬──────────┘
                             │                    │
                             ▼                    ▼
                      moved to done/      stays open with
                      Status: done        ## Progress notes
                                          next round retries
```

---

## Skills vs agents — what is the difference?

| Skills                                                                                                                              | Agents                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Instructions injected into the current conversation.                                                                                | Autonomous workers with their own isolated context window.                          |
| Invoked with `/slash-command`.                                                                                                      | Spawned by skills (Claude) or invoked directly (Copilot).                           |
| Shape how the AI thinks and responds right now.                                                                                     | Located in `.claude/agents/` (Claude) or `.github/agents/` (Copilot).               |
| No separate process — no extra cost beyond the current session.                                                                     | Each has its own tools, model, and instructions.                                    |
|                                                                                                                                     | Do the actual file editing, test running, and committing.                           |
| **Bundled examples:**<br>• `/afk-sprint` → runs the sprint<br>• `/solve-issue` → implements 1 issue<br>• `/tdd` → shapes test style | **Examples:**<br>• `coder` → implements issues<br>• `code-reviewer` → reviews diffs |

> Note: `/afk-sprint` is a **skill** in the Claude sandbox (it drives the workflow engine). `@afk-sprint` in Copilot is an **agent** (it runs the sprint loop itself). Same name, different primitive on each platform.

---

## Platform comparison

| Feature               | Claude Code                  | Copilot                                    |
| --------------------- | ---------------------------- | ------------------------------------------ |
| **Sprint model**      | Parallel (up to 8 at once)   | Sequential (one issue at a time)           |
| **Issue isolation**   | Git worktree per coder agent | Shared repo (no isolation)                 |
| **Sprint invocation** | `/afk-sprint` (skill)        | `@afk-sprint` (agent)                      |
| **Manual invocation** | `/solve-issue`               | `/solve-issue` (via Claude in the sandbox) |
| **Code review**       | Automatic at sprint end      | Automatic at protocol exit                 |
| **Best for**          | Large sprints, 5+ issues     | Smaller loads, already in Copilot          |

---

## Files that live in your project repo

When you use the sandbox, these files appear in your project. **Commit all of them** so the whole team shares them.

```
your-project/
├── .scratch/                        ← issue tracker (commit this)
│   └── <feature-slug>/
│       ├── PRD.md                   ← product requirements
│       └── issues/
│           ├── 01-*.md              ← Status: ready-for-agent
│           ├── 02-*.md
│           └── done/
│               └── 01-*.md         ← Status: done
│
├── .scratch/reviews/                ← code review reports (commit this)
│   └── sprint-review-<timestamp>.md
│
├── docs/agents/
│   ├── issue-tracker.md            ← override issue tracker conventions
│   └── triage-labels.md            ← override status label strings
│
└── .claude/
    └── skills/                     ← shared skills (both platforms)
        ├── tdd/
        ├── solve-issue/
        └── ...
```

---

## Common recipes

### Start a new feature (bundled tools only)

```bash
sbx-run claude-sbx
# Write .scratch/<feature>/issues/01-*.md manually, set Status: ready-for-agent
> /afk-sprint
```

### Start a new feature (with planning skills)

```bash
sbx-run claude-sbx
> /grill-me
> "I want to add X to our API"
> /to-prd
> /to-issues
> /afk-sprint
```

### Re-run sprint after fixing blockers

Resolve whatever was blocking an issue, then:

```
> /afk-sprint
```

It re-scans from scratch and picks up any issues that are now unblocked.

### Implement a single issue manually

```
> /solve-issue ".scratch/auth/issues/01-add-logout.md"
```

### Improve existing code architecture (requires optional skill)

```
> /improve-codebase-architecture
```

Surfaces refactoring opportunities informed by your CONTEXT.md and ADRs.

---

## Troubleshooting

| Symptom                                         | Likely cause                             | Fix                                                                        |
| ----------------------------------------------- | ---------------------------------------- | -------------------------------------------------------------------------- |
| Sprint picks up 0 issues                        | No `Status: ready-for-agent` files found | Check `.scratch/*/issues/*.md` — the status line must match exactly        |
| Issue keeps re-running each round               | Worker left it `partial`                 | Read its `## Progress` section, resolve the blocker, then re-run           |
| Sprint stalls after 2 rounds                    | All remaining issues are `blocked`       | Read each `## Blocked` section, resolve dependencies manually, then re-run |
| `setup.sh` fails                                | Missing `.env` variable                  | Check `~/.sbx-kits/.env` — copy from `.env.example` and fill every required field |
| `sbx-run` fails auth                        | AWS SSO session expired                  | Run `aws sso login --profile sso-live` before `sbx-run`                |
| Agent implements wrong thing                    | Issue acceptance criteria are ambiguous  | Rewrite criteria as testable bullet points, then re-run                    |
| `/grill-me`, `/to-prd`, `/to-issues` do nothing | Command not typed correctly              | Type the command exactly — e.g. `/grill-me` at the start of a new line     |

---

## Documentation map

| File                            | Audience                   | What it covers                                               |
| ------------------------------- | -------------------------- | ------------------------------------------------------------ |
| [README](../README.md)          | Anyone setting up the repo | Repo structure, configuration, one-time setup                |
| [docs/WORKFLOW.md](WORKFLOW.md) | Dev teams                  | This file — end-to-end team workflow                         |
| [docs/USAGE.md](USAGE.md)       | Developers wanting detail  | All bundled skills, agents, issue format, platform reference |
| `.scratch/*/PRD.md`             | The working team           | Feature requirements                                         |
| `.scratch/*/issues/*.md`        | Agents + team              | Implementation issues                                        |
| `.scratch/reviews/*.md`         | Team                       | Code review reports (created by sprint)                      |
| `docs/agents/issue-tracker.md`  | Project leads              | Override issue tracker conventions per project               |
| `docs/agents/triage-labels.md`  | Project leads              | Override status label strings per project                    |
