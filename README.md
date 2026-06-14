# SBX Templates

Composable sandbox templates for AI coding agents (Claude Code, GitHub Copilot). Agents provide the base runtime; kits layer in cloud auth, registry access, and pre-installed workflows.

## What this covers

### 1. Agents — Claude and Copilot, with or without Docker-in-sandbox

| Agent | Image | Docker inside? | Flag |
|---|---|---|---|
| `claude-docker` | `claude-code-docker` | yes | `--dangerously-skip-permissions` |
| `claude-sbx` | `claude-code` | no | `--dangerously-skip-permissions` |
| `copilot-docker` | `copilot-docker` | yes | `--yolo` |
| `copilot-sbx` | `copilot` | no | `--yolo` |

Pick `*-docker` when your project needs to build or run containers. Pick `*-sbx` for a lighter footprint.

### 2. Sandbox identity flags

Every agent sets two environment variables automatically:

```
SBX_NO_TELEMETRY=1   # disable telemetry inside the sandbox
IS_SANDBOX=1          # lets tooling and scripts detect they're running in a sandbox
```

### 3. Secure NPM token (`npm-auth` kit)

The `npm-auth` kit injects your `NPM_TOKEN` via the sandbox proxy — the token never touches the filesystem or shell history. The sandbox routes `registry.npmjs.org` traffic through the proxy and injects the `Authorization: Bearer <token>` header automatically.

Store the token in macOS Keychain and register it as a global sbx secret:

```bash
echo $(security find-generic-password -s 'npm_token' -w) | sbx secret set -g npm-auth
```

This reads from Keychain (not a file or env var) and pipes directly into the sbx secret store — the value never appears as a CLI argument or lands in shell history.

```bash
sbx-run claude-docker --kit npm-auth
```

### 4. AWS Bedrock via SSO (`aws-bedrock-sso` kit)

The `aws-bedrock-sso` kit mounts short-lived AWS credentials from your SSO session and configures Claude Code to route model calls through Amazon Bedrock. No long-lived keys — credentials refresh via `aws sso login`.

```bash
sbx-run claude-docker --kit aws-bedrock-sso
```

Configure via `~/.sbx-kits/.env`:

| Variable               | Required | Description                              |
| ---------------------- | -------- | ---------------------------------------- |
| `SSO_SUBDOMAIN`        | yes      | AWS SSO subdomain (before `.awsapps.com`) |
| `SSO_REGION`           | yes      | AWS region                               |
| `SSO_ROLE_NAME`        | yes      | IAM role name                            |
| `SSO_ACCOUNT_ID`       | yes      | AWS account ID                           |
| `BEDROCK_SONNET_MODEL` | no       | Default: `au.anthropic.claude-sonnet-4-6[1m]` |
| `BEDROCK_OPUS_MODEL`   | no       | Default: `au.anthropic.claude-opus-4-6-v1[1m]` |
| `BEDROCK_HAIKU_MODEL`  | no       | Default: `au.anthropic.claude-haiku-4-5-20251001-v1:0` |

### 5. Pre-installed workflow kit (`claude-wk` / `copilot-wk`)

The `claude-wk` and `copilot-wk` kits bootstrap the [coding-crew](https://github.com/ypxing/coding-crew) toolchain into the sandbox at create time. This gives the agent a pre-wired `/grill-me` workflow and the `/afk` (away-from-keyboard) autonomous coder — so you can start a long coding task and walk away.

```bash
sbx-run claude-docker --kit claude-wk
sbx-run copilot-docker --kit copilot-wk
```

Kits can be combined:

```bash
sbx-run claude-docker --kit aws-bedrock-sso --kit claude-wk
```

---

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
  claude-wk/                # coding-crew workflows for Claude (grill-me, afk)
  copilot-wk/               # coding-crew workflows for Copilot (grill-me, afk)
setup.sh                    # envsubst over all *.tpl files
sbx-run                     # smart sbx run wrapper
```

## Prerequisites

- **`sbx` CLI** — [Docker Sandbox](https://www.docker.com/products/sandbox/)
- **`jq`** — `brew install jq`
- **`envsubst`** — `brew install gettext`
- **AWS SSO access** with a Bedrock-enabled IAM role (for `aws-bedrock-sso` kit)

## Quick start

**1. Install (or update)**

```bash
curl -fsSL https://raw.githubusercontent.com/ypxing/docker-sbx-kits/main/install.sh | bash
```

**2. Configure (first time only — only needed for the `aws-bedrock-sso` kit)**

Edit `~/.sbx-kits/.env` with your SSO values, then run:

```bash
~/.sbx-kits/setup.sh
```

**3. Run from your project directory**

```bash
cd /path/to/project
```

Claude, no extras:

```bash
sbx-run
```

Claude with AWS Bedrock (requires step 2):

```bash
sbx-run claude-docker --kit aws-bedrock-sso
```

Claude with AWS Bedrock + private NPM registry:

```bash
sbx-run claude-docker --kit aws-bedrock-sso --kit npm-auth
```

GitHub Copilot:

```bash
sbx-run copilot-docker
```

List all available kits:

```bash
sbx-run --list-kits
```

`sbx-run` detects whether a sandbox already exists for the current directory:
- **First run** — creates sandbox with agent + specified kits
- **Subsequent runs** — resumes existing sandbox (kits ignored by sbx after create)

In both cases, `settings.fragment.json` files from the agent and all kits are deep-merged and injected as the final kit.

## Adding a new kit

```
kits/<name>/
  spec.yaml                       # or spec.src.yaml if it needs envsubst
  settings.fragment.json          # optional — merged into settings.json by sbx-run
  files/home/                     # optional — injected into sandbox ~/
```

Run `sbx-run --list-kits` to confirm it's discovered.
