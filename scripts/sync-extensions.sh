#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"
readonly SCRIPT_DIR
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly REPOSITORY_ROOT

if [[ -v CODESERVER_EXTENSIONS_LOCK_FILE ]]; then
  LOCK_FILE="$CODESERVER_EXTENSIONS_LOCK_FILE"
  if [[ "$LOCK_FILE" != /* ]]; then
    printf "FEHLER: CODESERVER_EXTENSIONS_LOCK_FILE muss absolut sein.\n" >&2
    exit 1
  fi
else
  LOCK_FILE="$REPOSITORY_ROOT/extensions.lock.txt"
fi
readonly LOCK_FILE

if [[ ! -f "$LOCK_FILE" || ! -r "$LOCK_FILE" ]]; then
  printf "FEHLER: Extension-Lockdatei fehlt oder ist nicht lesbar: %s\n" "$LOCK_FILE" >&2
  exit 1
fi

declare -A seen_extension_ids=()
declare -a locked_extensions=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  if [[ ! "$line" =~ ^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*@[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
    printf "FEHLER: Ungültiger Lockeintrag.\n" >&2
    exit 1
  fi

  extension_id="${line%@*}"
  normalized_id="${extension_id,,}"
  if [[ -v seen_extension_ids[$normalized_id] ]]; then
    printf "FEHLER: Doppelte Extension-ID in der Lockdatei: %s\n" "$extension_id" >&2
    exit 1
  fi
  seen_extension_ids[$normalized_id]=1
  locked_extensions+=("$line")
done < "$LOCK_FILE"

if (( ${#locked_extensions[@]} == 0 )); then
  printf "FEHLER: Extension-Lockdatei enthält keine Einträge.\n" >&2
  exit 1
fi

if ! command -v code-server >/dev/null 2>&1; then
  printf "FEHLER: code-server wurde nicht gefunden.\n" >&2
  exit 1
fi

declare -A installed_pins=()
while IFS= read -r installed_extension; do
  [[ -z "$installed_extension" ]] && continue
  installed_pins["${installed_extension,,}"]=1
done < <(code-server --list-extensions --show-versions)

printf "Synchronisiere exakt gepinnte code-server-Extensions ...\n\n"
for extension in "${locked_extensions[@]}"; do
  normalized_extension="${extension,,}"
  if [[ -v installed_pins[$normalized_extension] ]]; then
    printf "Vorhanden:   %s\n" "$extension"
    continue
  fi

  printf "Installiere: %s\n" "$extension"
  code-server --install-extension "$extension"
  installed_pins[$normalized_extension]=1
done

printf "\nExtension-Synchronisierung abgeschlossen.\n"
