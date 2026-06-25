# Docker SBX Kits

Run an AI coding agent in a Docker sandbox in one command — your project directory mounted, your cloud credentials wired up, your private registries accessible, and nothing leaking out of the container. Each sandbox is a composable combination of an agent template and optional add-on kits that snap together at create time, so you get exactly the environment you need without touching Dockerfiles or config files.

## 30-second demo

```bash
cd /your/project
sbx claude-docker --kit aws-bedrock-sso
```

You land in a Claude Code session with your project mounted and AWS Bedrock wired up. No long-lived keys, no manual credential plumbing — the kit handles it.

## Mental model

Pick one **agent** — it defines which AI tool runs and what the sandbox looks like. Layer on **kits** for anything extra: cloud auth, private registries, pre-installed workflows. Agents and kits are plain YAML and JSON fragments; `sbx` deep-merges them at sandbox create time. One agent, any number of kits, one command.

| Agent            | Docker inside? |
| ---------------- | -------------- |
| `claude-docker`  | yes            |
| `claude-sbx`     | no             |
| `copilot-docker` | yes            |
| `copilot-sbx`    | no             |

Pick `*-docker` when your project needs to build or run containers. Pick `*-sbx` for a lighter footprint.

## Setup

### Prerequisites

- **`sbx` CLI** — [Docker Sandbox](https://docs.docker.com/ai/sandboxes/)
- **`jq`** — `brew install jq`
- **`envsubst`** — `brew install gettext`

**1. Install (or update)**

```bash
curl -fsSL https://raw.githubusercontent.com/ypxing/docker-sbx-kits/main/install.sh | bash
```

The installer symlinks the `sbx` wrapper into your `$PATH`. Because Docker Desktop also ships an `sbx` CLI, the wrapper must come first — the installer warns you if it doesn't. If you see the warning, add this to your shell profile and restart your shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**2. Run from your project directory**

```bash
cd /path/to/project
```

Claude, no extras:

```bash
sbx
```

Claude with AWS Bedrock:

```bash
sbx claude-docker --kit aws-bedrock-sso
```

Claude with AWS Bedrock + private NPM:

```bash
sbx claude-docker --kit aws-bedrock-sso --kit npm-auth
```

GitHub Copilot:

```bash
sbx copilot-docker
```

List all available kits:

```bash
sbx --list-kits
```

`sbx` detects whether a sandbox already exists for the current directory:

- **First run** — creates sandbox with agent + specified kits
- **Subsequent runs** — resumes existing sandbox (kits ignored after create)

## Kits

### `aws-bedrock-sso` — AWS Bedrock via SSO

Mounts short-lived AWS credentials from your SSO session and routes Claude model calls through Amazon Bedrock. No long-lived keys.

**First-time setup:** edit `~/.sbx-kits/.env` with your SSO values, then run `~/.sbx-kits/setup.sh`.

| Variable               | Required | Description                                            |
| ---------------------- | -------- | ------------------------------------------------------ |
| `SSO_SUBDOMAIN`        | yes      | AWS SSO subdomain (before `.awsapps.com`)              |
| `SSO_REGION`           | yes      | AWS region                                             |
| `SSO_ROLE_NAME`        | yes      | IAM role name                                          |
| `SSO_ACCOUNT_ID`       | yes      | AWS account ID                                         |
| `BEDROCK_SONNET_MODEL` | no       | Default: `au.anthropic.claude-sonnet-4-6[1m]`          |
| `BEDROCK_OPUS_MODEL`   | no       | Default: `au.anthropic.claude-opus-4-6-v1[1m]`         |
| `BEDROCK_HAIKU_MODEL`  | no       | Default: `au.anthropic.claude-haiku-4-5-20251001-v1:0` |

### `npm-auth` — Secure NPM token

Injects your `NPM_TOKEN` via the sandbox proxy — the token never touches the filesystem or shell history.

Store the token in macOS Keychain and register it as a global sbx secret:

```bash
echo $(security find-generic-password -s 'npm_token' -w) | sbx secret set -g npm-auth
```

### `claude-wk` / `copilot-wk` — Pre-installed workflows

Bootstraps the [coding-crew](https://github.com/ypxing/coding-crew) toolchain into the sandbox, giving the agent a pre-wired `/grill-me` workflow and the `/afk` autonomous coder.

```bash
sbx claude-docker --kit claude-wk
sbx copilot-docker --kit copilot-wk
```

Kits can be combined:

```bash
sbx claude-docker --kit aws-bedrock-sso --kit claude-wk
```

## Structure

```
agents/
  claude-docker/            # Claude Code + Docker Desktop sandbox
  claude-sbx/               # Claude Code + lightweight sbx runtime
  copilot-docker/           # GitHub Copilot + Docker Desktop sandbox
  copilot-sbx/              # GitHub Copilot + lightweight sbx runtime
kits/
  aws-bedrock-sso/          # AWS SSO auth + Bedrock model routing
  npm-auth/                 # Secure NPM registry auth via proxy
  claude-wk/                # coding-crew workflows for Claude
  copilot-wk/               # coding-crew workflows for Copilot
setup.sh                    # envsubst over all *.tpl files
sbx                     # smart sbx run wrapper
```

## Adding a new kit

```
kits/<name>/
  spec.yaml                 # or spec.src.yaml if it needs envsubst
  settings.fragment.json    # optional — merged into settings.json by sbx
  files/home/               # optional — injected into sandbox ~/
```

Run `sbx --list-kits` to confirm it's discovered.
