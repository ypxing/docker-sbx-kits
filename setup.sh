#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for cmd in envsubst jq; do
  command -v "$cmd" >/dev/null || { echo "Error: $cmd not found. Install: brew install ${cmd/envsubst/gettext}"; exit 1; }
done

if [ ! -f .env ]; then
  echo "Error: .env not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source .env

: "${SSO_SUBDOMAIN:?SSO_SUBDOMAIN is required in .env}"
: "${SSO_REGION:?SSO_REGION is required in .env}"
: "${SSO_ROLE_NAME:?SSO_ROLE_NAME is required in .env}"
: "${SSO_ACCOUNT_ID:?SSO_ACCOUNT_ID is required in .env}"

export SSO_SUBDOMAIN SSO_REGION SSO_ROLE_NAME SSO_ACCOUNT_ID
export BEDROCK_SONNET_MODEL="${BEDROCK_SONNET_MODEL:-au.anthropic.claude-sonnet-4-6[1m]}"
export BEDROCK_OPUS_MODEL="${BEDROCK_OPUS_MODEL:-au.anthropic.claude-opus-4-6-v1[1m]}"
export BEDROCK_HAIKU_MODEL="${BEDROCK_HAIKU_MODEL:-au.anthropic.claude-haiku-4-5-20251001-v1:0}"

VARS='$SSO_SUBDOMAIN:$SSO_REGION:$SSO_ROLE_NAME:$SSO_ACCOUNT_ID:$BEDROCK_SONNET_MODEL:$BEDROCK_OPUS_MODEL:$BEDROCK_HAIKU_MODEL'

# Process all spec.src.yaml → spec.yaml under agents/ and kits/
while IFS= read -r src; do
  envsubst "$VARS" < "$src" > "${src/spec.src.yaml/spec.yaml}"
done < <(find agents kits -name "spec.src.yaml")

# Process all other .tpl files — output strips the .tpl suffix
while IFS= read -r tpl; do
  envsubst "$VARS" < "$tpl" > "${tpl%.tpl}"
done < <(find agents kits -name "*.tpl")

echo "Configuration:"
echo "  SSO_SUBDOMAIN  = ${SSO_SUBDOMAIN}"
echo "  SSO_REGION     = ${SSO_REGION}"
echo "  SSO_ROLE_NAME  = ${SSO_ROLE_NAME}"
echo "  SSO_ACCOUNT_ID = ${SSO_ACCOUNT_ID:0:4}************"
echo ""
echo "Generated:"
find agents kits -name "spec.src.yaml" | sed 's/spec\.src\.yaml/spec.yaml/'
find agents kits -name "*.tpl" | sed 's/\.tpl$//'
