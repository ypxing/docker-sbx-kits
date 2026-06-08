---
name: dep-install
description: >
  Detect the project's install mode (host or docker) and install dependencies once.
  Used as a shared step by solve-issue, address-code-review, and address-pr-comments.
---

# Dep Install

Install project dependencies once before doing any code work.

## Skip condition

If no dependency signal files exist (`package.json`, `go.mod`, `requirements.txt`,
`pyproject.toml`, `Cargo.toml`, `pom.xml`, `*.csproj`, `Gemfile`, `composer.json`,
`mix.exs`, `uv.lock`, `bun.lockb`, `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`,
`poetry.lock`, `go.sum`), skip this entire skill.

## Never

- Never read, log, print, or inspect the contents of `.env*`, `.npmrc*`, or `.yarnrc*` files.
- Never modify lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `uv.lock`, etc.).

## Detect install mode

Run this script and follow the path it outputs — **do not proceed until you have run it**:

```bash
PROJECT_ROOT=$(pwd)

# 1. Explicit git config override
_mode=$(git -C "$PROJECT_ROOT" config --local agent.install-mode 2>/dev/null)

# 2. Infer from Makefile install/deps/setup targets
if [ -z "$_mode" ]; then
  if [ -f "$PROJECT_ROOT/Makefile" ]; then
    _direct=$(awk '
      /^[^_][a-zA-Z0-9_-]*[[:space:]]*:/ { in_target = /install|deps|setup/ }
      in_target && /^\t/ { print }
    ' "$PROJECT_ROOT/Makefile")

    _private=$(echo "$_direct" | grep -oE '\b_[a-zA-Z0-9_-]+' || true)

    _indirect=""
    if [ -n "$_private" ]; then
      _indirect=$(awk -v targets="$_private" '
        BEGIN { n=split(targets, t); for (i in t) tset[t[i]]=1 }
        /^(_[a-zA-Z0-9_-]+)[[:space:]]*:/ { in_target = ($1 in tset) }
        in_target && /^\t/ { print }
      ' "$PROJECT_ROOT/Makefile")
    fi

    echo "$_direct $_indirect" | grep -qE 'docker-compose|docker compose' && _mode="docker"
  fi
fi

# 3. Fall back to compose-file presence
if [ -z "$_mode" ]; then
  { [ -f "$PROJECT_ROOT/docker-compose.yml" ] || \
    [ -f "$PROJECT_ROOT/docker-compose.yaml" ] || \
    [ -f "$PROJECT_ROOT/compose.yml" ]; } \
    && _mode="docker" || _mode="host"
fi

[ "$_mode" = "docker" ] && echo "USE_DOCKER" || echo "USE_HOST"
```

- `USE_DOCKER` → Follow [docker-install.md](docker-install.md) (`.claude/skills/dep-install/docker-install.md`) **for all subsequent commands** — install, test, lint, everything. Never fall back to host commands because `node_modules` exists on the host.
- `USE_HOST` → Follow [host-install.md](host-install.md) (`.claude/skills/dep-install/host-install.md`)

To override, run once in the project root:
```bash
git config --local agent.install-mode host   # or: docker
```
This is stored in `.git/config` and visible from all worktrees.

## Rules

- Run install **once**. Only re-run if a new package is added during implementation.
- If install fails due to missing auth tokens, network errors, or Docker not running — stop immediately and report blocked with verbatim output. Do not attempt workarounds.
