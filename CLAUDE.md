# Docker SBX Kits

Sandbox templates for AI coding agents with composable kits.

## Layout

- `agents/` — agent templates (`claude-docker`, `claude-sbx`, `copilot-docker`, `copilot-sbx`)
- `kits/` — optional add-ons merged in at sandbox create time (`aws-bedrock-sso`, `npm-auth`)
- `setup.sh` — runs `envsubst` over all `*.tpl` files under `agents/` and `kits/`
- `sbx` — smart wrapper: detects existing sandbox, merges `settings.fragment.json` files

## Key rules

- Edit `spec.src.yaml` — never `spec.yaml` (generated)
- Edit `settings.fragment.json` or `settings.fragment.json.tpl` in the agent or kit root — never a merged output
- Never commit `.env`
- Each `spec.yaml` `name` field must match its directory name
- `claude-docker` uses `--dangerously-skip-permissions` (sandbox-only)
- `copilot-docker` uses `--yolo` (sandbox-only)

## Settings fragments

`sbx` deep-merges `settings.fragment.json` from the agent dir then each kit dir (in order):
- Objects: recursively merged, last kit wins per key
- Arrays (`permissions.allow/deny`, `hooks.*`): concatenated and deduped
- Scalars: last kit wins

## Adding a new kit

1. Create `kits/<name>/`
2. Add `spec.yaml` (or `spec.src.yaml` + `.tpl` if it needs env var substitution)
3. Optionally add `settings.fragment.json` (or `.tpl`) for settings contributions
4. Optionally add `files/` for files to inject into the sandbox home
