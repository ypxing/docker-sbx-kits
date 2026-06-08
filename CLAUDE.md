# SBX Templates

Sandbox templates for AI coding agents (Claude Code, GitHub Copilot) with AWS Bedrock and optional NPM auth.

## Layout

- `claude-sbx/` and `copilot-sbx/` are the two templates
- Each has two source specs: `spec.base.yaml` (no NPM) and `spec.npm.yaml` (with NPM)
- `setup.sh` copies the right one to `spec.yaml` (git-ignored) based on `USE_NPM` in `.env`, then replaces `<YOUR_...>` placeholders

## Key rules

- Edit `spec.base.yaml` or `spec.npm.yaml` — never edit `spec.yaml` directly (it's generated)
- Edit `files/` directly in each template directory
- Never commit `.env` — it contains org-specific values; `.env.example` is the committed template
- Placeholders use the pattern `<YOUR_VARIABLE_NAME>` in spec files and .aws/config
- Each generated `spec.yaml` has a `name` field that must match its directory name
- Claude templates use `--dangerously-skip-permissions` entrypoint (sandbox-only)
- Copilot templates use `--yolo` entrypoint (sandbox-only)

## Specs

Each template's spec files define:
- `agent.image` — Docker image to use
- `agent.entrypoint` — Command to run
- `environment.variables` — Env vars set in sandbox
- `environment.proxyManaged` — Secrets injected by the proxy (not in files)
- `network.allowedDomains` — Network allowlist
- `commands.install` — Setup commands run at sandbox init

The `spec.npm.yaml` variant additionally includes NPM registry auth, service routing, and credentials.
