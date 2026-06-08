---
name: solve-issue
description: >
  Implement a single issue end-to-end: read it, explore context, install deps, build with TDD,
  verify checks, and commit. Platform-agnostic — works in worktrees or branches.
argument-hint: "Path to issue file (e.g. .scratch/auth/issues/01-add-logout.md)"
---

# Solve Issue

Implement a single issue. One issue in, committed code out.

## Blocked output format

When stopping due to a blocker, always output:

```
BLOCKED: <reason>
<verbatim error or dependency name>
```

Do not attempt workarounds. Do not proceed.

## Inputs

The caller provides one of:
- A **file path** — read the issue from that path.
- **Issue content** inline — use it directly.

The caller also establishes `PROJECT_ROOT` (where to read/write code). If not explicit, use `pwd`.

## Steps

### 0. Pre-flight

Run `git -C "$PROJECT_ROOT" status --short`. If there are modified or staged tracked files not owned by this issue, stop and report blocked: `BLOCKED: dirty worktree — stash or commit unrelated changes first`.

### 1. Understand the issue

**Finding the issue file:** Issues live as local markdown files in `.scratch/`. Read from the path
the caller provides. Do **not** query GitHub (`gh`) or any remote issue tracker unless the caller
explicitly says to.

Extract from the issue:
- Acceptance criteria
- Hypothesized files likely to change (confirmed in Step 2)
- Blocked-by dependencies — if any are unresolved, stop and report blocked.

### 2. Explore before coding

For each hypothesized file from Step 1:
1. Read the source file.
2. Read the corresponding test file if one exists.
3. Note test style, naming conventions, and patterns — these become the style contract for Step 4.

Expand the file list if exploration reveals additional files. Do not guess. Confirm the current state before writing anything.

### 3. Install dependencies

Follow the `dep-install` skill (`.claude/skills/dep-install/SKILL.md`) to detect install mode and install dependencies. Run install **once** at this step; only re-run if you add a new package during implementation.

### 4. Implement with TDD

Follow the `tdd` skill (`.claude/skills/tdd/SKILL.md`): plan → tracer bullet → incremental red/green loop → refactor. Honor the style contract from Step 2.

Apply `karpathy-guidelines` (`.claude/skills/karpathy-guidelines/SKILL.md`) throughout — surgical changes, simplicity, goal-driven execution.

If either skill file is not installed, apply reasonable defaults: write a failing test first, then implement to make it pass, then refactor.

### 5. Verify

Run all project checks and confirm every acceptance criterion is met.
See [verification.md](verification.md) (`.claude/skills/solve-issue/verification.md`) for how to discover and run checks.

Do not proceed to commit if any check fails or any criterion is unmet.

### 6. Commit

If there are no staged changes after implementation, verify the issue was already done and report accordingly — do not error.

Stage only the files you changed — never `git add .` or `git add -A`.

Commit message format:
```
<issue title>

- <key decision or tradeoff — omit if none>
```

If the caller specifies a `Co-Authored-By:` git trailer, append it verbatim as the last line.

Do not push.

### 7. Mark done

Read `docs/agents/issue-tracker.md` (at `$PROJECT_ROOT/docs/agents/issue-tracker.md`) and follow its "mark the ticket done" instructions using the issue file path from Step 1.

If the file does not exist, skip this step.
