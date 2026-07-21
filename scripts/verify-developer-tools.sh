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
  jq
  lsof
  make
  nc
  node
  npm
  ping
  pnpm
  ps
  pwsh
  python3
  rg
  rsync
  shellcheck
  ssh
  tree
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

echo "Versionsinformationen:"
echo

printf 'codeserver.example.com:      '
node --version

printf 'npm:          '
npm --version

printf 'pnpm:         '
pnpm --version

printf 'Codex:        '
codex --version

printf 'PowerShell:   '
pwsh --version

printf 'Git:          '
git --version

printf 'Python:       '
python3 --version

printf 'ripgrep:      '
rg --version | head -n 1

printf 'fd:           '
fd --version

printf 'rsync:        '
rsync --version | head -n 1

printf 'ShellCheck:   '
shellcheck --version \
  | awk -F': ' '/^version:/ { print $2; exit }'

printf 'tree:         '
tree --version

echo
echo "Alle Entwicklerwerkzeuge sind vorhanden."
