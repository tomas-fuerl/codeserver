#!/usr/bin/env bash
set -euo pipefail

EXPECTED_NODE="v24.18.0"
EXPECTED_GH="2.96.0"
EXPECTED_PNPM="11.4.0"
EXPECTED_PSQL_PREFIX="psql (PostgreSQL) 18.4"
EXPECTED_PG_ISREADY_PREFIX="pg_isready (PostgreSQL) 18.4"
EXPECTED_PG_DUMP_PREFIX="pg_dump (PostgreSQL) 18.4"
EXPECTED_PG_RESTORE_PREFIX="pg_restore (PostgreSQL) 18.4"
EXPECTED_DOCKER_PREFIX="Docker version 29.7.0"
EXPECTED_COMPOSE_PREFIX="Docker Compose version v5.3.1"
EXPECTED_BUILDX_PREFIX="github.com/docker/buildx v0.36.0"
EXPECTED_TRIVY_PREFIX="Version: 0.72.0"
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
  actual="$("$@" | sed -n '1p' | tr -d '\r')"

  echo "OK: ${name}: ${actual}"
}
check_prefix() {
  local name="$1"
  local expected_prefix="$2"
  shift 2

  local actual
  actual="$("$@" | sed -n '1p' | tr -d '\r')"

  if [[ "$actual" != "${expected_prefix}"* ]]; then
    echo "FEHLER: ${name}"
    echo "  Erwartet: ${expected_prefix}..."
    echo "  Gefunden: ${actual}"
    return 1
  fi

  echo "OK: ${name}: ${actual}"
}

github_cli_version() {
  gh --version | awk 'NR == 1 { print $3; exit }'
}

check_exact "Node.js" "$EXPECTED_NODE" node --version
check_available "npm" npm --version
check_exact "pnpm" "$EXPECTED_PNPM" pnpm --version
check_prefix "psql" "$EXPECTED_PSQL_PREFIX" psql --version
check_prefix "pg_isready" "$EXPECTED_PG_ISREADY_PREFIX" pg_isready --version
check_prefix "pg_dump" "$EXPECTED_PG_DUMP_PREFIX" pg_dump --version
check_prefix "pg_restore" "$EXPECTED_PG_RESTORE_PREFIX" pg_restore --version
check_prefix "Docker CLI" "$EXPECTED_DOCKER_PREFIX" docker --version
check_prefix "Docker Compose" "$EXPECTED_COMPOSE_PREFIX" docker compose version
check_prefix "Docker Buildx" "$EXPECTED_BUILDX_PREFIX" docker buildx version
check_prefix "Trivy" "$EXPECTED_TRIVY_PREFIX" trivy --version
check_exact "PowerShell" "$EXPECTED_POWERSHELL" pwsh --version
check_exact "Codex CLI" "$EXPECTED_CODEX" codex --version
check_available "Git" git --version
check_available "jq" jq --version
check_exact "GitHub CLI" "$EXPECTED_GH" github_cli_version
check_available "curl" curl --version

if [[ -S /var/run/docker.sock ]]; then
  echo "FEHLER: Docker-Socket ist vorhanden." >&2
  exit 1
fi
if command -v dockerd >/dev/null 2>&1 || command -v containerd >/dev/null 2>&1; then
  echo "FEHLER: Docker-Daemon oder containerd ist vorhanden." >&2
  exit 1
fi

echo
echo "Toolchain vollständig, versionskonform und daemonfrei."
