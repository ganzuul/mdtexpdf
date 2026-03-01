#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DO_INSTALL=false
CONVERT_FILE=""

usage() {
  cat <<'EOF'
Usage: scripts/verify-install.sh [--install] [--convert <file.md>]

Checks:
  1) Which mdtexpdf binary is on PATH
  2) Resolved binary path
  3) mdtexpdf --version
  4) Workspace vs installed script sync (mdtexpdf.sh)
  5) Workspace vs installed module sync (preprocess.sh, template.sh)

Options:
  --install            Run built-in install first (equivalent to: make build)
  --convert <file.md>  Run a conversion smoke test with default prompt answers
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      DO_INSTALL=true
      shift
      ;;
    --convert)
      [[ $# -ge 2 ]] || { echo "error: --convert requires a file path" >&2; exit 2; }
      CONVERT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

pass() { echo "✓ $*"; }
warn() { echo "! $*"; }
info() { echo "- $*"; }

if $DO_INSTALL; then
  info "Installing current workspace build via built-in target (make build)..."
  make build
  pass "Install completed"
fi

info "Checking active mdtexpdf on PATH..."
if ! command -v mdtexpdf >/dev/null 2>&1; then
  echo "error: mdtexpdf not found on PATH" >&2
  exit 1
fi

BIN_PATH="$(command -v mdtexpdf)"
BIN_REAL="$(readlink -f "$BIN_PATH")"

pass "PATH binary: $BIN_PATH"
pass "Resolved binary: $BIN_REAL"

info "Version info..."
mdtexpdf --version

EXPECTED_USER_BIN="$HOME/.local/bin/mdtexpdf"
if [[ "$BIN_REAL" == "$EXPECTED_USER_BIN" ]]; then
  pass "Active binary is user-local install ($EXPECTED_USER_BIN)"
else
  warn "Active binary is not ~/.local/bin/mdtexpdf (verify this is intended)"
fi

INST_LIB_DIR="$HOME/.local/share/mdtexpdf/lib"
if [[ ! -d "$INST_LIB_DIR" ]]; then
  warn "Installed lib directory not found: $INST_LIB_DIR"
else
  pass "Installed lib directory present: $INST_LIB_DIR"
fi

info "Checking workspace vs installed script/library sync..."
if cmp -s "$ROOT_DIR/mdtexpdf.sh" "$BIN_REAL"; then
  pass "mdtexpdf.sh matches installed PATH binary"
else
  warn "mdtexpdf.sh differs from installed PATH binary"
fi

if [[ -f "$INST_LIB_DIR/preprocess.sh" ]]; then
  if cmp -s "$ROOT_DIR/lib/preprocess.sh" "$INST_LIB_DIR/preprocess.sh"; then
    pass "lib/preprocess.sh matches installed copy"
  else
    warn "lib/preprocess.sh differs from installed copy"
  fi
fi

if [[ -f "$INST_LIB_DIR/template.sh" ]]; then
  if cmp -s "$ROOT_DIR/lib/template.sh" "$INST_LIB_DIR/template.sh"; then
    pass "lib/template.sh matches installed copy"
  else
    warn "lib/template.sh differs from installed copy"
  fi
fi

if [[ -n "$CONVERT_FILE" ]]; then
  if [[ ! -f "$CONVERT_FILE" ]]; then
    echo "error: convert file not found: $CONVERT_FILE" >&2
    exit 1
  fi

  info "Running conversion smoke test with installed binary: $CONVERT_FILE"
  LOG_FILE="/tmp/mdtexpdf_verify_convert.log"
  printf '\n\n\n\n\n\n\n\n\n\n' | mdtexpdf convert "$CONVERT_FILE" >"$LOG_FILE" 2>&1 || true

  if grep -q "Success! PDF created as" "$LOG_FILE"; then
    pass "Conversion smoke test succeeded"
  else
    warn "Conversion smoke test did not report success"
    warn "See log: $LOG_FILE"
    tail -n 40 "$LOG_FILE" || true
  fi
fi

pass "Verification script completed"
