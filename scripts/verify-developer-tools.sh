#!/usr/bin/env bash
set -euo pipefail

required_commands=(
  bash
  codex
  curl
  dig
  fd
  g++
  gcc
  git
  gh
  jq
  lsof
  make
  nc
  node
  npm
  ping
  pnpm
  psql
  pg_isready
  pg_dump
  pg_restore
  docker
  ps
  pwsh
  python3
  rg
  rsync
  shellcheck
  ssh
  tree
  trivy
  unzip
  zip
)

has_errors=false

echo "Prüfe installierte Entwicklerwerkzeuge ..."
echo

for command_name in "${required_commands[@]}"; do
  if command_path="$(command -v "$command_name" 2>/dev/null)"; then
    printf 'OK:     %-12s %s\n' "$command_name" "$command_path"
  else
    printf 'FEHLER: %-12s nicht gefunden\n' "$command_name" >&2
    has_errors=true
  fi
done

echo

if [[ "$has_errors" == true ]]; then
  echo "Mindestens ein erforderliches Werkzeug fehlt." >&2
  exit 1
fi

if [[ -S /var/run/docker.sock ]]; then
  echo "FEHLER: Docker-Socket ist im normalen code-server vorhanden." >&2
  exit 1
fi
if command -v dockerd >/dev/null 2>&1 || command -v containerd >/dev/null 2>&1; then
  echo "FEHLER: Docker-Daemon oder containerd ist im normalen code-server vorhanden." >&2
  exit 1
fi

echo "Versionsinformationen:"
echo

printf 'Node.js:      '
node --version

printf 'npm:          '
npm --version

printf 'pnpm:         '
pnpm --version

printf 'PostgreSQL:   '
psql --version
printf 'pg_isready:   '
pg_isready --version
printf 'pg_dump:      '
pg_dump --version
printf 'pg_restore:   '
pg_restore --version
printf 'Docker CLI:   '
docker --version
printf 'Compose V2:   '
docker compose version
printf 'Buildx:       '
docker buildx version
printf 'Trivy:        '
trivy --version

printf 'Codex:        '
codex --version

printf 'PowerShell:   '
pwsh --version

printf 'Git:          '
git --version
printf 'GitHub CLI:   '
gh --version | awk 'NR == 1 { print $3; exit }'

printf 'Python:       '
python3 --version

printf 'ripgrep:      '
rg --version | sed -n '1p'

printf 'fd:           '
fd --version

printf 'rsync:        '
rsync --version | sed -n '1p'

printf 'ShellCheck:   '
shellcheck --version \
  | awk -F': ' '/^version:/ { print $2; exit }'

printf 'tree:         '
tree --version

echo
echo "Alle Entwicklerwerkzeuge sind vorhanden."
