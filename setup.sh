#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Error: .env not found. Copy .env.example to .env and fill in your values."
  echo "  cp .env.example .env"
  exit 1
fi

source .env

: "${SSO_SUBDOMAIN:?SSO_SUBDOMAIN is required in .env}"
: "${SSO_REGION:?SSO_REGION is required in .env}"
: "${SSO_ROLE_NAME:?SSO_ROLE_NAME is required in .env}"
: "${SSO_ACCOUNT_ID:?SSO_ACCOUNT_ID is required in .env}"

USE_NPM="${USE_NPM:-true}"

# Pick the right spec variant and output as spec.yaml (what sbx run reads)
for dir in claude-sbx copilot-sbx; do
  if [ "$USE_NPM" = "true" ]; then
    cp "$dir/spec.npm.yaml" "$dir/spec.yaml"
  else
    cp "$dir/spec.base.yaml" "$dir/spec.yaml"
  fi
done

# Replace AWS placeholders in claude-sbx
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' \
    -e "s|<YOUR_SSO_SUBDOMAIN>|${SSO_SUBDOMAIN}|g" \
    -e "s|<YOUR_REGION>|${SSO_REGION}|g" \
    -e "s|<YOUR_ROLE_NAME>|${SSO_ROLE_NAME}|g" \
    -e "s|<YOUR_ACCOUNT_ID>|${SSO_ACCOUNT_ID}|g" \
    claude-sbx/spec.yaml \
    claude-sbx/files/home/.aws/config
else
  sed -i \
    -e "s|<YOUR_SSO_SUBDOMAIN>|${SSO_SUBDOMAIN}|g" \
    -e "s|<YOUR_REGION>|${SSO_REGION}|g" \
    -e "s|<YOUR_ROLE_NAME>|${SSO_ROLE_NAME}|g" \
    -e "s|<YOUR_ACCOUNT_ID>|${SSO_ACCOUNT_ID}|g" \
    claude-sbx/spec.yaml \
    claude-sbx/files/home/.aws/config
fi

echo "Generated: claude-sbx/spec.yaml (USE_NPM=$USE_NPM)"
echo "Generated: copilot-sbx/spec.yaml (USE_NPM=$USE_NPM)"
echo ""
echo "Run your sandbox with:"
echo "  sbx run claude-sbx --kit ./claude-sbx/"
echo "  sbx run copilot-sbx --kit ./copilot-sbx/"
