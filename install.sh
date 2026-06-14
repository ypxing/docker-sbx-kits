#!/usr/bin/env bash
# install.sh — install or update docker-sbx-kits
# Usage: curl -fsSL https://raw.githubusercontent.com/ypxing/docker-sbx-kits/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/ypxing/docker-sbx-kits.git"
INSTALL_DIR="${SBX_KITS_DIR:-$HOME/.sbx-kits}"
BIN_CANDIDATES=("$HOME/.local/bin" "$HOME/.bin" "/usr/local/bin")

# ── helpers ───────────────────────────────────────────────────────────────────

info()    { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn()    { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()     { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git not found"
command -v jq  >/dev/null || die "jq not found — install: brew install jq"

# ── install or update ─────────────────────────────────────────────────────────

if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Updating $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only
else
  info "Cloning into $INSTALL_DIR"
  git clone "$REPO" "$INSTALL_DIR"
fi

# ── symlink sbx-run ───────────────────────────────────────────────────────────

BIN_DIR=""
for candidate in "${BIN_CANDIDATES[@]}"; do
  if [[ -d "$candidate" && -w "$candidate" ]]; then
    BIN_DIR="$candidate"
    break
  fi
done

if [[ -z "$BIN_DIR" ]]; then
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
  warn "$BIN_DIR created — make sure it is in your PATH"
fi

ln -sf "$INSTALL_DIR/sbx-run" "$BIN_DIR/sbx-run"
success "sbx-run → $BIN_DIR/sbx-run"

# ── .env setup ────────────────────────────────────────────────────────────────

ENV_FILE="$INSTALL_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$INSTALL_DIR/.env.example" "$ENV_FILE"
  warn "Edit $ENV_FILE with your AWS SSO values if you use AWS-backed agents."
fi

# Always run setup to generate spec.yaml files (required before sbx-run works)
info "Running setup.sh"
"$INSTALL_DIR/setup.sh"
echo ""
success "Done. Run sbx-run from any project directory."
