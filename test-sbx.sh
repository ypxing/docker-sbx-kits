#!/usr/bin/env bash
# Tests for sbx + install.sh rename
# Run: bash test-sbx.sh
set -euo pipefail

PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3: expected '$2' got '$1'"; fi; }
assert_contains() { if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3: '$1' does not contain '$2'"; fi; }
assert_file_exists() { if [[ -f "$1" ]]; then pass "$2"; else fail "$2: file not found: $1"; fi; }
assert_is_symlink() { if [[ -L "$1" ]]; then pass "$2"; else fail "$2: not a symlink: $1"; fi; }

# ── Setup shared temp dir ──────────────────────────────────────────────────────
TMPBASE=$(mktemp -d)
trap 'rm -rf "$TMPBASE"' EXIT

# Helper: create a minimal install dir that looks like a cloned repo
# (has a .git with remote so install.sh git pull succeeds, and a setup.sh that succeeds)
make_fake_install_dir() {
  local dir="$1"
  # Create a bare "origin" repo
  local origin="$dir-origin"
  git init --bare "$origin" -q
  # Clone from it
  git clone --quiet "$origin" "$dir" 2>/dev/null
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
  # Add required files
  cp "$PROJECT_ROOT/sbx" "$dir/sbx"
  cp "$PROJECT_ROOT/install.sh" "$dir/install.sh"
  touch "$dir/.env.example"
  echo '#!/usr/bin/env bash' > "$dir/setup.sh"
  chmod +x "$dir/setup.sh" "$dir/sbx"
  git -C "$dir" add .
  git -C "$dir" commit -q -m "init"
  git -C "$dir" push -q origin HEAD 2>/dev/null
}

# Helper: create a fake sbx binary that records its invocations
make_fake_sbx() {
  local path="$1"
  cat > "$path" <<'FAKESBX'
#!/usr/bin/env bash
echo "CALLED:$*"
FAKESBX
  chmod +x "$path"
}

# ── Test 1: install.sh writes .sbx_path ───────────────────────────────────────
T1_DIR="$TMPBASE/t1"
T1_INSTALL="$T1_DIR/install"
T1_BIN="$T1_DIR/bin"
mkdir -p "$T1_DIR" "$T1_BIN"
make_fake_install_dir "$T1_INSTALL"

# Create a fake 'sbx' binary (named sbx so command -v sbx finds it)
T1_FAKE_BIN_DIR="$T1_DIR/fakebin"
mkdir -p "$T1_FAKE_BIN_DIR"
make_fake_sbx "$T1_FAKE_BIN_DIR/sbx"

PATH="$T1_FAKE_BIN_DIR:$PATH" SBX_KITS_DIR="$T1_INSTALL" SBX_KITS_BIN="$T1_BIN" \
  bash "$T1_INSTALL/install.sh" >/dev/null 2>&1 || true

assert_file_exists "$T1_INSTALL/.sbx_path" "install.sh writes .sbx_path"

SBX_PATH_CONTENT=$(cat "$T1_INSTALL/.sbx_path" 2>/dev/null || true)
if [[ -n "$SBX_PATH_CONTENT" ]]; then pass "install.sh .sbx_path is non-empty"; else fail "install.sh .sbx_path is empty"; fi
assert_contains "$SBX_PATH_CONTENT" "fakebin/sbx" "install.sh .sbx_path contains valid path to sbx binary"

# ── Test 2: install.sh symlinks sbx (not sbx-run) ─────────────────────────────
T2_DIR="$TMPBASE/t2"
T2_INSTALL="$T2_DIR/install"
T2_BIN="$T2_DIR/bin"
mkdir -p "$T2_DIR" "$T2_BIN"
make_fake_install_dir "$T2_INSTALL"

T2_FAKE_BIN_DIR="$T2_DIR/fakebin"
mkdir -p "$T2_FAKE_BIN_DIR"
make_fake_sbx "$T2_FAKE_BIN_DIR/sbx"

PATH="$T2_FAKE_BIN_DIR:$PATH" SBX_KITS_DIR="$T2_INSTALL" SBX_KITS_BIN="$T2_BIN" \
  bash "$T2_INSTALL/install.sh" >/dev/null 2>&1 || true

assert_is_symlink "$T2_BIN/sbx" "install.sh creates sbx symlink"

LINK_TARGET=$(readlink "$T2_BIN/sbx" 2>/dev/null || echo "")
assert_eq "$LINK_TARGET" "$T2_INSTALL/sbx" "sbx symlink points to INSTALL_DIR/sbx"

if [[ ! -e "$T2_BIN/sbx-run" ]]; then pass "install.sh does not create sbx-run symlink"; else fail "install.sh created sbx-run symlink (should not)"; fi

# ── Test 3: collision warning for non-symlink sbx in bin dir ──────────────────
T3_DIR="$TMPBASE/t3"
T3_INSTALL="$T3_DIR/install"
T3_BIN="$T3_DIR/bin"
mkdir -p "$T3_DIR" "$T3_BIN"
make_fake_install_dir "$T3_INSTALL"

T3_FAKE_BIN_DIR="$T3_DIR/fakebin"
mkdir -p "$T3_FAKE_BIN_DIR"
make_fake_sbx "$T3_FAKE_BIN_DIR/sbx"

echo "not a symlink" > "$T3_BIN/sbx"
chmod +x "$T3_BIN/sbx"

COLLISION_OUT=$(PATH="$T3_FAKE_BIN_DIR:$PATH" SBX_KITS_DIR="$T3_INSTALL" SBX_KITS_BIN="$T3_BIN" \
  bash "$T3_INSTALL/install.sh" 2>&1 || true)

assert_contains "$COLLISION_OUT" "exists and is not a symlink" "install.sh warns about non-symlink sbx collision"
T3_SBX_CONTENT=$(cat "$T3_BIN/sbx")
if [[ "$T3_SBX_CONTENT" == "not a symlink" ]]; then pass "install.sh does not overwrite non-symlink sbx"; else fail "install.sh overwrote non-symlink sbx"; fi

# ── Test 4: sbx errors clearly when .sbx_path missing ─────────────────────────
T4_DIR="$TMPBASE/t4"
T4_INSTALL="$T4_DIR/install"
mkdir -p "$T4_INSTALL"
cp "$PROJECT_ROOT/sbx" "$T4_INSTALL/sbx"
# No .sbx_path written

ERROR_OUT=$(bash "$T4_INSTALL/sbx" ls 2>&1 || true)
assert_contains "$ERROR_OUT" "install.sh" "sbx errors clearly when .sbx_path missing"
if bash "$T4_INSTALL/sbx" ls >/dev/null 2>&1; then fail "sbx exits 0 when .sbx_path missing"; else pass "sbx exits non-zero when .sbx_path missing"; fi

# ── Test 5: sbx passthrough subcommands forwarded via $SBX ────────────────────
T5_DIR="$TMPBASE/t5"
T5_INSTALL="$T5_DIR/install"
mkdir -p "$T5_INSTALL"
cp "$PROJECT_ROOT/sbx" "$T5_INSTALL/sbx"

T5_FAKE_SBX="$T5_DIR/fake_sbx_bin"
make_fake_sbx "$T5_FAKE_SBX"
echo "$T5_FAKE_SBX" > "$T5_INSTALL/.sbx_path"

for subcmd in ls rm stop; do
  OUT=$(bash "$T5_INSTALL/sbx" "$subcmd" 2>&1 || true)
  assert_contains "$OUT" "CALLED:$subcmd" "sbx forwards '$subcmd' via \$SBX"
done

# ── Test 6: re-run install.sh writes real sbx (not wrapper) to .sbx_path ────────
T6_DIR="$TMPBASE/t6"
T6_INSTALL="$T6_DIR/install"
T6_BIN="$T6_DIR/bin"
mkdir -p "$T6_DIR" "$T6_BIN"
make_fake_install_dir "$T6_INSTALL"

T6_FAKE_BIN_DIR="$T6_DIR/fakebin"
mkdir -p "$T6_FAKE_BIN_DIR"
make_fake_sbx "$T6_FAKE_BIN_DIR/sbx"

# First install — puts wrapper symlink at T6_BIN/sbx
PATH="$T6_FAKE_BIN_DIR:$PATH" SBX_KITS_DIR="$T6_INSTALL" SBX_KITS_BIN="$T6_BIN" \
  bash "$T6_INSTALL/install.sh" >/dev/null 2>&1 || true

# Second install (re-run) — wrapper symlink now precedes fakebin on PATH
# Without the guard, command -v sbx would find the wrapper and write it to .sbx_path
PATH="$T6_BIN:$T6_FAKE_BIN_DIR:$PATH" SBX_KITS_DIR="$T6_INSTALL" SBX_KITS_BIN="$T6_BIN" \
  bash "$T6_INSTALL/install.sh" >/dev/null 2>&1 || true

T6_SBX_PATH=$(cat "$T6_INSTALL/.sbx_path" 2>/dev/null || true)
# .sbx_path must point to the fake real binary, not to the wrapper
if [[ "$T6_SBX_PATH" == "$T6_INSTALL/sbx" ]]; then
  fail "re-install wrote wrapper path to .sbx_path (would cause infinite recursion)"
else
  assert_contains "$T6_SBX_PATH" "fakebin/sbx" "re-install .sbx_path points to real sbx (not wrapper)"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then exit 0; else exit 1; fi
