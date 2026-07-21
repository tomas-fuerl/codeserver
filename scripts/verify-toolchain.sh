#!/usr/bin/env bash
set -euo pipefail

EXPECTED_NODE="v24.18.0"
EXPECTED_PNPM="10.13.1"
EXPECTED_POWERSHELL="PowerShell 7.6.3"
EXPECTED_CODEX="codex-cli 0.144.5"

check_exact() {
  local name="$1"
  local expected="$2"
  shift 2

  local actual
  actual="$("$@" | tr -d '\r')"

  if [[ "$actual" != "$expected" ]]; then
    echo "FEHLER: ${name}"
    echo "  Erwartet: ${expected}"
    echo "  Gefunden: ${actual}"
    return 1
  fi

  echo "OK: ${name}: ${actual}"
}

check_available() {
  local name="$1"
  shift

  local actual
  actual="$("$@" | head -n 1 | tr -d '\r')"

  echo "OK: ${name}: ${actual}"
}

check_exact "codeserver.example.com" "$EXPECTED_NODE" node --version
check_available "npm" npm --version
check_exact "pnpm" "$EXPECTED_PNPM" pnpm --version
check_exact "PowerShell" "$EXPECTED_POWERSHELL" pwsh --version
check_exact "Codex CLI" "$EXPECTED_CODEX" codex --version
check_available "Git" git --version
check_available "jq" jq --version
check_available "curl" curl --version

echo
echo "Toolchain vollständig und versionskonform."
