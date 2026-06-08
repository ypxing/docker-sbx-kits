# Host Install

Use this when no `docker-compose.yml`, `docker-compose.yaml`, or `compose.yml` exists at `PROJECT_ROOT`.

## Detect and run

Check signal files in order — use the first match:

| Signal file | Install command |
|---|---|
| `uv.lock` | `uv sync` |
| `bun.lockb` | `bun install` |
| `pnpm-lock.yaml` | `CI=true pnpm install --prefer-offline` |
| `package-lock.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `poetry.lock` | `poetry install` |
| `go.sum` / `go.mod` | `go mod download` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `pyproject.toml` (no lock above) | `pip install -e .` |
| `Gemfile.lock` | `bundle install` |
| `Cargo.toml` | `cargo fetch` |
| `composer.json` | `composer install` |
| `pom.xml` | `mvn dependency:resolve -q` |
| `*.csproj` | `dotnet restore` |
| `mix.exs` | `mix deps.get` |

## Rules

- Run install **once**. Only re-run if you add a new package during implementation.
- Never inject auth tokens or dummy credentials.
- If install fails due to environment issues, stop and report blocked with verbatim output.
- Do not run `make install` or other project-defined install targets — they often bundle steps
  that are wrong outside the normal development setup. (SKILL.md reads the Makefile only to
  detect install mode; this rule applies to execution.)
