#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

readonly CONFIG_ROOT="${CODESERVER_CONFIG_ROOT:-CHANGE_ME}"
readonly SECRET_ROOT="${CODESERVER_SECRET_ROOT:-CHANGE_ME}"
readonly RESTORE_ROOT="${CODESERVER_RESTORE_ROOT:-CHANGE_ME}"
readonly CONTAINER_NAME="${CODESERVER_CONTAINER_NAME:-CHANGE_ME}"
readonly GIT_CHECK_COMMAND="git -c safe.directory='*' -C \"\$1\" rev-parse --is-inside-work-tree"

fail() {
  printf '[restore-test] FEHLER: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf 'Aufruf: %s --archive <ARCHIV> --target <LEERES_ZIELVERZEICHNIS>\n' "$0" >&2
  exit 2
}

validate_absolute_root() {
  local name="$1"
  local path="$2"

  [[ "$path" == /* && "$path" != "/" ]] ||
    fail "${name} muss ein absoluter Pfad unterhalb von / sein."
  [[ "$path" != */ && "$path" != *"//"* &&
    "/${path#/}/" != *"/./"* && "/${path#/}/" != *"/../"* ]] ||
    fail "${name} muss lexikalisch normalisiert und ohne abschließenden Slash angegeben werden."
}

paths_overlap() {
  local first="$1"
  local second="$2"

  [[ "$first" == "$second" || "$first" == "$second"/* || "$second" == "$first"/* ]]
}

canonicalize_target_path() {
  local path="$1"
  local suffix=""
  local base=""
  local resolved=""

  while [[ ! -e "$path" && "$path" != "/" ]]; do
    base="$(basename -- "$path")"
    suffix="/${base}${suffix}"
    path="$(dirname -- "$path")"
  done

  [[ -d "$path" ]] || return 1
  resolved="$(cd -- "$path" && pwd -P)"
  printf '%s%s\n' "$resolved" "$suffix"
}

archive=""
target=""
while (( $# > 0 )); do
  case "$1" in
    --archive)
      (( $# >= 2 )) || usage
      archive="$2"
      shift 2
      ;;
    --target)
      (( $# >= 2 )) || usage
      target="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "$archive" && -n "$target" ]] || usage

if [[ -z "$CONFIG_ROOT" || "$CONFIG_ROOT" == "CHANGE_ME" ||
  -z "$SECRET_ROOT" || "$SECRET_ROOT" == "CHANGE_ME" ||
  -z "$RESTORE_ROOT" || "$RESTORE_ROOT" == "CHANGE_ME" ||
  -z "$CONTAINER_NAME" || "$CONTAINER_NAME" == "CHANGE_ME" ]]; then
  fail "CODESERVER_CONFIG_ROOT, CODESERVER_SECRET_ROOT, CODESERVER_RESTORE_ROOT und CODESERVER_CONTAINER_NAME müssen explizit konfiguriert sein."
fi

validate_absolute_root "CODESERVER_CONFIG_ROOT" "$CONFIG_ROOT"
validate_absolute_root "CODESERVER_SECRET_ROOT" "$SECRET_ROOT"
validate_absolute_root "CODESERVER_RESTORE_ROOT" "$RESTORE_ROOT"
validate_absolute_root "Archivpfad" "$archive"
validate_absolute_root "Restore-Ziel" "$target"
[[ "$CONTAINER_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] ||
  fail "CODESERVER_CONTAINER_NAME enthält unzulässige Zeichen."

if paths_overlap "$CONFIG_ROOT" "$SECRET_ROOT" ||
  paths_overlap "$CONFIG_ROOT" "$RESTORE_ROOT" ||
  paths_overlap "$SECRET_ROOT" "$RESTORE_ROOT"; then
  fail "Config-, Secret- und Restore-Root müssen vollständig getrennt sein."
fi
[[ "$target" == "$RESTORE_ROOT"/* ]] ||
  fail "Das Restore-Ziel muss strikt unter CODESERVER_RESTORE_ROOT liegen."

[[ -d "$CONFIG_ROOT" && ! -L "$CONFIG_ROOT" ]] ||
  fail "Produktiver Config-Root fehlt oder ist ein Symlink: ${CONFIG_ROOT}"
[[ -d "$SECRET_ROOT" && ! -L "$SECRET_ROOT" ]] ||
  fail "Produktiver Secret-Root fehlt oder ist ein Symlink: ${SECRET_ROOT}"
[[ -d "$RESTORE_ROOT" && ! -L "$RESTORE_ROOT" ]] ||
  fail "Restore-Root fehlt oder ist ein Symlink: ${RESTORE_ROOT}"
[[ -f "$archive" && ! -L "$archive" ]] || fail "Archiv fehlt oder ist ein Symlink: ${archive}"

resolved_config="$(cd -- "$CONFIG_ROOT" && pwd -P)"
readonly resolved_config
resolved_protected_root="$(cd -- "$SECRET_ROOT" && pwd -P)"
readonly resolved_protected_root
resolved_restore="$(cd -- "$RESTORE_ROOT" && pwd -P)"
readonly resolved_restore
resolved_target="$(canonicalize_target_path "$target")" ||
  fail "Der Zielpfad kann nicht sicher aufgelöst werden: ${target}"
readonly resolved_target

if paths_overlap "$resolved_config" "$resolved_protected_root" ||
  paths_overlap "$resolved_config" "$resolved_restore" ||
  paths_overlap "$resolved_protected_root" "$resolved_restore"; then
  fail "Aufgelöste Config-, Secret- und Restore-Pfade überlappen."
fi
[[ "$resolved_target" == "$resolved_restore"/* ]] ||
  fail "Das aufgelöste Restore-Ziel liegt nicht unter CODESERVER_RESTORE_ROOT."
[[ "$resolved_target" != "$resolved_config" && "$resolved_target" != "$resolved_protected_root" ]] ||
  fail "Produktiver Config- oder Secret-Root darf niemals Restore-Ziel sein."

checksum_file="${archive}.sha256"
[[ -f "$checksum_file" && ! -L "$checksum_file" ]] ||
  fail "Prüfsummendatei fehlt oder ist ein Symlink: ${checksum_file}"

archive_dir="$(dirname -- "$archive")"
checksum_name="$(basename -- "$checksum_file")"
if ! (cd -- "$archive_dir" && sha256sum --check --status "$checksum_name"); then
  fail "SHA-256-Prüfung fehlgeschlagen: ${archive}"
fi

listing="$(mktemp /tmp/codeserver-restore-list.XXXXXX)"
trap 'rm -f -- "$listing"' EXIT
tar -tzf "$archive" >"$listing" || fail "Tar-Archiv ist nicht lesbar: ${archive}"

workspace_found=false
data_found=false
codex_found=false
secret_file_count=0
while IFS= read -r entry; do
  [[ "$entry" != /* ]] || fail "Unsicherer absoluter Pfad im Archiv: ${entry}"
  entry="${entry#./}"
  [[ "/${entry}/" != *"/../"* ]] || fail "Unsicherer Elternpfad im Archiv: ${entry}"
  case "$entry" in
    workspace|workspace/*)
      workspace_found=true
      ;;
    data|data/*)
      data_found=true
      ;;
    .codex|.codex/*)
      codex_found=true
      ;;
    secrets/hashed_password)
      ((secret_file_count += 1))
      ;;
  esac
done <"$listing"
[[ "$workspace_found" == true ]] || fail "workspace/ fehlt im Archiv."
[[ "$data_found" == true ]] || fail "data/ fehlt im Archiv."
[[ "$codex_found" == true ]] || fail ".codex/ fehlt im Archiv."
(( secret_file_count == 1 )) ||
  fail "secrets/hashed_password fehlt oder ist nicht eindeutig im Archiv enthalten."

if ! secret_metadata="$(tar -tvzf "$archive" -- ./secrets/hashed_password)"; then
  fail "Metadaten von secrets/hashed_password konnten nicht gelesen werden."
fi
read -r secret_mode _ <<<"$secret_metadata"
[[ "$secret_mode" == "-rw-------" ]] ||
  fail "secrets/hashed_password hat im Archiv nicht den Modus 0600."

if ! secret_size="$(tar -xOzf "$archive" -- ./secrets/hashed_password | wc -c)"; then
  fail "secrets/hashed_password konnte nicht auf Nicht-Leere geprüft werden."
fi
(( secret_size > 0 )) || fail "secrets/hashed_password ist im Archiv leer."

if [[ -e "$resolved_target" ]]; then
  [[ -d "$resolved_target" && ! -L "$resolved_target" ]] ||
    fail "Das Restore-Ziel existiert und ist kein reguläres Verzeichnis: ${resolved_target}"
  if find "$resolved_target" -mindepth 1 -maxdepth 1 -print -quit | read -r _; then
    fail "Das Restore-Ziel ist nicht leer: ${resolved_target}"
  fi
else
  mkdir -p -- "$resolved_target"
fi

command -v docker >/dev/null 2>&1 || fail "Docker ist nicht verfügbar."
if ! IMAGE="$(docker inspect --format '{{.Config.Image}}' "$CONTAINER_NAME")"; then
  fail "Das Hilfsimage des Containers ${CONTAINER_NAME} konnte nicht ermittelt werden."
fi
readonly IMAGE
[[ -n "$IMAGE" ]] || fail "Das Hilfsimage des Containers ist leer."

printf '[restore-test] Extrahiere geprüftes Archiv nach %s ...\n' "$resolved_target"
tar --numeric-owner -xzf "$archive" -C "$resolved_target"

[[ -d "${resolved_target}/workspace" ]] || fail "workspace/ fehlt nach dem Restore."
[[ -d "${resolved_target}/data" ]] || fail "data/ fehlt nach dem Restore."
[[ -d "${resolved_target}/.codex" ]] || fail ".codex/ fehlt nach dem Restore."
[[ -f "${resolved_target}/secrets/hashed_password" &&
  ! -L "${resolved_target}/secrets/hashed_password" ]] ||
  fail "secrets/hashed_password fehlt nach dem Restore oder ist keine reguläre Datei."
[[ -s "${resolved_target}/secrets/hashed_password" ]] ||
  fail "secrets/hashed_password ist nach dem Restore leer."
[[ "$(stat -c '%a' -- "${resolved_target}/secrets/hashed_password")" == "600" ]] ||
  fail "secrets/hashed_password hat nach dem Restore nicht den Modus 0600."

repository_count=0
while IFS= read -r -d '' git_marker; do
  repository="$(dirname -- "$git_marker")"
  repository_relative="${repository#"${resolved_target}/"}"
  container_repository="/restore/${repository_relative}"
  if ! docker run --rm \
    --user abc \
    --entrypoint /bin/bash \
    --mount "type=bind,source=${resolved_target},target=/restore,readonly" \
    "$IMAGE" \
    -c "$GIT_CHECK_COMMAND" \
    restore-git-check "$container_repository" >/dev/null; then
    fail "Git-Repository ist ungültig: ${repository}"
  fi
  ((repository_count += 1))
done < <(find "${resolved_target}/workspace" -name .git -print0)

printf '[restore-test] ERFOLG: Nicht-destruktiver Restore-Test abgeschlossen.\n'
printf '[restore-test] Restore-Ziel: %s\n' "$resolved_target"
printf '[restore-test] Geprüfte Git-Repositories: %d\n' "$repository_count"
