#!/usr/bin/env bash
set -Eeuo pipefail

readonly BACKUP_DIR="/example/path"

fail() {
  printf '[verify] FEHLER: %s\n' "$*" >&2
  exit 1
}

(( $# <= 1 )) || fail "Aufruf: $0 [ARCHIVPFAD]"

if (( $# == 1 )); then
  ARCHIVE="$1"
  [[ "$ARCHIVE" == /* ]] || fail "Der Archivpfad muss absolut sein."
else
  mapfile -t archives < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'codeserver-config-????????-??????.tar.gz' -print 2>/dev/null | sort)
  (( ${#archives[@]} > 0 )) || fail "Kein Backup-Archiv in ${BACKUP_DIR} gefunden."
  ARCHIVE="${archives[${#archives[@]} - 1]}"
fi
readonly ARCHIVE
readonly CHECKSUM_FILE="${ARCHIVE}.sha256"

[[ -f "$ARCHIVE" ]] || fail "Archiv fehlt: ${ARCHIVE}"
[[ -f "$CHECKSUM_FILE" ]] || fail "Prüfsummendatei fehlt: ${CHECKSUM_FILE}"

archive_dir="$(dirname -- "$ARCHIVE")"
checksum_name="$(basename -- "$CHECKSUM_FILE")"
if ! (cd "$archive_dir" && sha256sum --check --status "$checksum_name"); then
  fail "SHA-256-Prüfung fehlgeschlagen: ${ARCHIVE}"
fi

listing="$(mktemp /tmp/codeserver.example.com)"
trap 'rm -f -- "$listing"' EXIT
tar -tzf "$ARCHIVE" >"$listing" || fail "Tar-Archiv ist nicht lesbar: ${ARCHIVE}"

workspace_found=false
data_found=false
codex_found=false
secret_file_count=CHANGE_ME
while IFS= read -r entry; do
  [[ "$entry" != /* ]] || fail "Unsicherer absoluter Pfad im Archiv: ${entry}"
  entry="${entry#./}"
  [[ "/${entry}/" != *"/../"* ]] || fail "Unsicherer Elternpfad im Archiv: ${entry}"
  case "$entry" in
    workspace|workspace/*) workspace_found=true ;;
    data|data/*) data_found=true ;;
    .codex|.codex/*) codex_found=true ;;
    secrets/hashed_password) ((secret_file_count += 1)) ;;
  esac
done <"$listing"

[[ "$workspace_found" == true ]] || fail "workspace/ fehlt im Archiv."
[[ "$data_found" == true ]] || fail "data/ fehlt im Archiv."
[[ "$codex_found" == true ]] || fail ".codex/ fehlt im Archiv."
(( secret_file_count == 1 )) || fail "secrets/hashed_password fehlt oder ist nicht eindeutig im Archiv enthalten."

if ! secret_metadata="$(tar -tvzf "$ARCHIVE" -- ./secrets/hashed_password)"; then
  fail "Metadaten von secrets/hashed_password konnten nicht gelesen werden."
fi
read -r secret_mode _ <<<"$secret_metadata"
[[ "$secret_mode" == "-rw-------" ]] || fail "secrets/hashed_password hat im Archiv nicht den Modus 0600."

if ! secret_size="$(tar -xOzf "$ARCHIVE" -- ./secrets/hashed_password | wc -c)"; then
  fail "secrets/hashed_password konnte nicht auf Inhalt geprüft werden."
fi
(( secret_size > 0 )) || fail "secrets/hashed_password ist im Archiv leer."

printf '[verify] ERFOLG: Prüfsumme, Tar-Struktur, Pflichtverzeichnisse und Secret-Datei sind gültig: %s\n' "$ARCHIVE"
