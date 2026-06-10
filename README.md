# SBX Templates

Composable sandbox templates for AI coding agents (Claude Code, GitHub Copilot). Agents provide the base runtime; kits layer in cloud auth, registry access, and settings.

## Structure

```
agents/
  claude-docker/            # Claude Code base (no cloud assumptions)
  copilot-docker/           # GitHub Copilot base
kits/
  aws-bedrock-sso/          # AWS SSO auth + Bedrock routing + AWS CLI
  npm-auth/                 # NPM registry auth
setup.sh                    # envsubst over all *.tpl files
sbx-run                     # smart sbx run wrapper
```

## Prerequisites

- **`sbx` CLI** — [Docker Sandbox](https://www.docker.com/products/sandbox/)
- **`jq`** — `brew install jq`
- **`envsubst`** — `brew install gettext`
- **AWS SSO access** with a Bedrock-enabled IAM role (for `aws-bedrock-sso` kit)

## Quick start

```bash
# 1. Clone and symlink
git clone <repo-url> ~/sbx-template
ln -s ~/sbx-template/sbx-run /usr/local/bin/sbx-run

# 2. Configure
cp ~/sbx-template/.env.example ~/sbx-template/.env
# edit .env with your SSO values

# 3. Generate config files
~/sbx-template/setup.sh

# 4. Run from your project directory
cd /path/to/project
sbx-run                                          # claude-docker, no kits
sbx-run claude-docker --kit aws-bedrock-sso      # with AWS Bedrock
sbx-run claude-docker --kit aws-bedrock-sso --kit npm-auth
sbx-run copilot-docker
sbx-run --list-kits
```

`sbx-run` detects whether a sandbox already exists for the current directory:
- **First run** — creates sandbox with agent + specified kits
- **Subsequent runs** — resumes existing sandbox (kits ignored by sbx after create)

In both cases, `settings.fragment.json` files from the agent and all kits are deep-merged and injected as the final kit.

## .env variables

| Variable               | Required | Description                              |
| ---------------------- | -------- | ---------------------------------------- |
| `SSO_SUBDOMAIN`        | yes      | AWS SSO subdomain (before `.awsapps.com`) |
| `SSO_REGION`           | yes      | AWS region                               |
| `SSO_ROLE_NAME`        | yes      | IAM role name                            |
| `SSO_ACCOUNT_ID`       | yes      | AWS account ID                           |
| `BEDROCK_SONNET_MODEL` | no       | Default: `au.anthropic.claude-sonnet-4-6[1m]` |
| `BEDROCK_OPUS_MODEL`   | no       | Default: `au.anthropic.claude-opus-4-6-v1[1m]` |
| `BEDROCK_HAIKU_MODEL`  | no       | Default: `au.anthropic.claude-haiku-4-5-20251001-v1:0` |

## Adding a new kit

```
kits/<name>/
  spec.yaml                       # or spec.src.yaml if it needs envsubst
  settings.fragment.json          # optional — merged into settings.json by sbx-run
  files/home/                     # optional — injected into sandbox ~/
```

Run `sbx-run --list-kits` to confirm it's discovered.
