# Docker Install

Use this when `docker-compose.yml`, `docker-compose.yaml`, or `compose.yml` exists at `PROJECT_ROOT`.
Do **not** run any install command on the host — everything runs inside the container.

`PROJECT_ROOT` is the working directory at invocation time (`pwd`). It is the worktree root when
running inside a git worktree, or the repo root otherwise — both cases are handled identically.

## Never

- Never run any install or project command on the host — everything runs inside the container.
- Never fall back to host commands because `node_modules` exists on the host.
- Never use `docker-compose` (v1 hyphenated binary) — always use `docker compose` (v2 plugin).
- Always pass both `-f "$PROJECT_ROOT/docker-compose.yml" -f "$PROJECT_ROOT/docker-compose.override.yml"` on every `docker compose` command after step 3. Omitting either `-f` flag disables auto-merge and breaks the override.

## Steps

### 0. Read Makefile and ensure `.env` exists

**a. Read the Makefile** (`$PROJECT_ROOT/Makefile`), if present. Scan for:
   - Targets that reference `.env` (e.g. `cp .env.example .env`, `$(MAKE) .env`)
   - Environment variable names used in recipes (e.g. `$(NPM_TOKEN)`, `export FOO`)
   - Any comments describing required secrets or setup
   - Targets that generate `.npmrc` or `.yarnrc.yml` (e.g. `gen-npmrc`, `$(MAKE) .npmrc`, `envsubst`)

This step is always done — the Makefile reveals how the project works and what env vars are expected.

**b. If `.env` does not exist at `PROJECT_ROOT`:**

   - If `.env.example` exists: `cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"`
   - Otherwise: `touch "$PROJECT_ROOT/.env"`

**b2. Generate `.npmrc` / `.yarnrc.yml` if the Makefile has a target for it:**

   - If the Makefile contains a target that generates `.npmrc` or `.yarnrc.yml` (look for recipes
     using `envsubst`, `echo`, or template files like `.npmrc.tpl`, `.yarnrc.yml.tpl`), run that
     target now:
     ```bash
     make -C "$PROJECT_ROOT" <target-name>
     ```
   - If no Makefile target exists but `.npmrc.tpl` or `.yarnrc.yml.tpl` is present, generate via
     `envsubst`:
     ```bash
     envsubst < "$PROJECT_ROOT/.npmrc.tpl" > "$PROJECT_ROOT/.npmrc"
     # or
     envsubst < "$PROJECT_ROOT/.yarnrc.yml.tpl" > "$PROJECT_ROOT/.yarnrc.yml"
     ```
   - Skip silently if neither a target nor a template file exists.

**c.** Log what was done (e.g. "Created .env from .env.example; generated .yarnrc.yml from Makefile target").

**Never read the contents of `.env*`, `.npmrc*`, or `.yarnrc*` files** — not to log, not to inspect, not to verify.

Always continue to step 1 — this step never blocks. If `docker compose` later fails because a
required env var is missing, stop and report blocked with the verbatim error.

### 1. Read the compose file

Note:
- The service name (e.g. `serverless`)
- The container-side source mount path (e.g. `/opt/app`) — call it `CONTAINER_SRC`
- Any environment variable references in the file (e.g. `${MAIN_ROOT}`, `${APP_ROOT}`) — pass each one inline on every `docker compose` call

### 2. Derive slug and find all vendor directories

```bash
SLUG=$(basename "$PROJECT_ROOT" | tr -cs 'a-zA-Z0-9' '_' | sed 's/_$//')
```

Named volumes (scoped to this worktree's slug) shadow the bind-mount at vendor paths so each
worktree gets its own isolated, clean directory. Docker named volumes always start empty, so
**install must always run inside the container** regardless of whether `node_modules` exists on
the host.

**For Node.js** — find every `package.json` under `PROJECT_ROOT` (excluding `node_modules`
directories) and add a named volume for each:

```bash
find "$PROJECT_ROOT" -name 'package.json' \
  -not -path '*/node_modules/*' \
  -maxdepth 5 \
  | while read -r pkg; do
      dir=$(dirname "$pkg")
      # host path relative to PROJECT_ROOT
      rel="${dir#$PROJECT_ROOT/}"
      # container path
      [ "$rel" = "$dir" ] && container_path="$CONTAINER_SRC/node_modules" \
                          || container_path="$CONTAINER_SRC/$rel/node_modules"
      # volume name: replace / and - with _
      suffix=$(echo "$rel" | tr '/-' '__' | sed 's/^$/root/')
      echo "volume: wt_${SLUG}_nm_${suffix}  ->  ${container_path}"
    done
```

For other ecosystems, apply the same pattern using these signal files:

| Ecosystem | Signal file | Vendor dir |
|---|---|---|
| Python | `requirements.txt` / `pyproject.toml` | `venv` or `.venv` |
| Ruby | `Gemfile` | `vendor/bundle` |
| Go | `go.mod` | `vendor` (if present) |
| PHP | `composer.json` | `vendor` |
| Rust | `Cargo.toml` | `target` |
| Java | `pom.xml` | `target` |
| .NET | `*.csproj` | `obj`, `bin` |

### 3. Write `docker-compose.override.yml`

Use the volume list produced in step 2 to write the override file. Every volume appears in both
the service `volumes:` list and the top-level `volumes:` block.

**Check `IS_SANDBOX`** before writing:

```bash
[ "$IS_SANDBOX" = "1" ] && SANDBOX=true || SANDBOX=false
```

If `SANDBOX=true`, add `environment` and the CA bundle volume mount to every service in the
override. Merge everything into one file — do **not** create a second override file.

Example output for a project with `package.json` at root, `events/`, and `tenants/`
(service name read from compose file as `<service>`, `CONTAINER_SRC=/opt/app`, `SLUG=myproject`):

Non-sandbox (`IS_SANDBOX` unset or `0`):

```yaml
services:
  <service>:
    volumes:
      - wt_myproject_nm_root:/opt/app/node_modules
      - wt_myproject_nm_events:/opt/app/events/node_modules
      - wt_myproject_nm_tenants:/opt/app/tenants/node_modules

volumes:
  wt_myproject_nm_root:
  wt_myproject_nm_events:
  wt_myproject_nm_tenants:
```

Sandbox (`IS_SANDBOX=1`) — same file, extra `environment` and CA mount added:

```yaml
services:
  <service>:
    environment:
      - HTTPS_PROXY
      - YARN_HTTPS_PROXY=${HTTPS_PROXY}
      - NODE_EXTRA_CA_CERTS
    volumes:
      - wt_myproject_nm_root:/opt/app/node_modules
      - wt_myproject_nm_events:/opt/app/events/node_modules
      - wt_myproject_nm_tenants:/opt/app/tenants/node_modules
      - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro

volumes:
  wt_myproject_nm_root:
  wt_myproject_nm_events:
  wt_myproject_nm_tenants:
```

### 4. Run install once

Named volumes start empty — always run install inside the container, even if `node_modules`
exists on the host. The install command must populate **every** `node_modules` that has a named
volume.

Prefer the Makefile install target if it covers all sub-packages. Otherwise run the package
manager in each `package.json` directory explicitly:

```bash
docker compose \
  -f "$PROJECT_ROOT/docker-compose.yml" \
  -f "$PROJECT_ROOT/docker-compose.override.yml" \
  run --rm <service-from-compose-file> sh -c "<install for each package.json dir>"
```

Pass both `-f` flags (auto-merge is disabled when `-f` is used).

### 5. All subsequent `docker compose` commands must pass both `-f` flags

## Install failures

If install fails because the container ignores `<install-command>` (entrypoint override), check
the compose file for an `entrypoint:` key and adjust:
```bash
docker compose ... run --rm --entrypoint sh <service-from-compose-file> -c "<install-command>"
```

If install fails due to missing auth tokens, network errors, or Docker not running — stop
immediately and report blocked with the verbatim error. Do not attempt workarounds.
