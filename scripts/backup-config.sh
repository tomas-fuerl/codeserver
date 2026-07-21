#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

readonly SOURCE_DIR="${CODESERVER_CONFIG_ROOT:-CHANGE_ME}"
readonly SECRET_DIR="${CODESERVER_SECRET_ROOT:-CHANGE_ME}"
readonly BACKUP_DIR="${CODESERVER_BACKUP_ROOT:-CHANGE_ME}"
readonly CONTAINER_NAME="${CODESERVER_CONTAINER_NAME:-CHANGE_ME}"
readonly SECRET_FILE="${SECRET_DIR}/hashed_password"

early_fail() {
  printf '[backup] FEHLER: %s\n' "$*" >&2
  exit 1
}

validate_absolute_root() {
  local name="$1"
  local path="$2"

  [[ "$path" == /* && "$path" != "/" ]] ||
    early_fail "${name} muss ein absoluter Pfad unterhalb von / sein."
  [[ "$path" != */ && "$path" != *"//"* &&
    "/${path#/}/" != *"/./"* && "/${path#/}/" != *"/../"* ]] ||
    early_fail "${name} muss lexikalisch normalisiert und ohne abschließenden Slash angegeben werden."
}

paths_overlap() {
  local first="$1"
  local second="$2"

  [[ "$first" == "$second" || "$first" == "$second"/* || "$second" == "$first"/* ]]
}

if [[ -z "$SOURCE_DIR" || "$SOURCE_DIR" == "CHANGE_ME" ||
  -z "$SECRET_DIR" || "$SECRET_DIR" == "CHANGE_ME" ||
  -z "$BACKUP_DIR" || "$BACKUP_DIR" == "CHANGE_ME" ||
  -z "$CONTAINER_NAME" || "$CONTAINER_NAME" == "CHANGE_ME" ]]; then
  early_fail "CODESERVER_CONFIG_ROOT, CODESERVER_SECRET_ROOT, CODESERVER_BACKUP_ROOT und CODESERVER_CONTAINER_NAME müssen explizit konfiguriert sein."
fi

validate_absolute_root "CODESERVER_CONFIG_ROOT" "$SOURCE_DIR"
validate_absolute_root "CODESERVER_SECRET_ROOT" "$SECRET_DIR"
validate_absolute_root "CODESERVER_BACKUP_ROOT" "$BACKUP_DIR"
[[ "$CONTAINER_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] ||
  early_fail "CODESERVER_CONTAINER_NAME enthält unzulässige Zeichen."

if paths_overlap "$SOURCE_DIR" "$SECRET_DIR" ||
  paths_overlap "$SOURCE_DIR" "$BACKUP_DIR" ||
  paths_overlap "$SECRET_DIR" "$BACKUP_DIR"; then
  early_fail "Config-, Secret- und Backupverzeichnis müssen vollständig getrennt sein."
fi

readonly LOCK_DIR="${BACKUP_DIR}/.backup.lock"

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"
readonly SCRIPT_DIR
readonly VERIFY_SCRIPT="${SCRIPT_DIR}/verify-backup.sh"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
readonly TIMESTAMP
readonly ARCHIVE_NAME="codeserver-config-${TIMESTAMP}.tar.gz"
readonly ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
readonly CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"
readonly MANIFEST_PATH="${ARCHIVE_PATH}.manifest.txt"
readonly STAGE_DIR="${BACKUP_DIR}/.stage-${TIMESTAMP}"

container_was_running=false
container_stopped=false
lock_acquired=false
PROTECTED_STAGE_DIR=""

log() {
  printf '[backup] %s\n' "$*"
}

fail() {
  printf '[backup] FEHLER: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local exit_code=$?

  if [[ "$container_stopped" == true ]]; then
    log "Starte ${CONTAINER_NAME} nach Fehler wieder ..."
    if docker start "$CONTAINER_NAME" >/dev/null; then
      container_stopped=false
    else
      printf '[backup] FEHLER: Container %s konnte nicht neu gestartet werden.\n' "$CONTAINER_NAME" >&2
      exit_code=1
    fi
  fi

  if [[ -d "$STAGE_DIR" ]] && ! rm -rf -- "$STAGE_DIR"; then
    printf '[backup] FEHLER: Arbeitskopie konnte nicht entfernt werden: %s\n' "$STAGE_DIR" >&2
    exit_code=1
  fi
  if [[ -n "$PROTECTED_STAGE_DIR" && -d "$PROTECTED_STAGE_DIR" ]] &&
    ! rm -rf -- "$PROTECTED_STAGE_DIR"; then
    printf '[backup] FEHLER: Secret-Staging-Verzeichnis konnte nicht entfernt werden.\n' >&2
    exit_code=1
  fi
  if [[ "$lock_acquired" == true ]]; then
    rmdir -- "$LOCK_DIR" 2>/dev/null || true
  fi

  exit "$exit_code"
}
trap cleanup EXIT

[[ "$EUID" -eq 0 ]] || fail "Dieses Skript muss als root ausgeführt werden."
[[ -d "$SOURCE_DIR" && ! -L "$SOURCE_DIR" ]] ||
  fail "Configverzeichnis fehlt oder ist ein Symlink: ${SOURCE_DIR}"
[[ -d "$SECRET_DIR" && ! -L "$SECRET_DIR" ]] ||
  fail "Secret-Verzeichnis fehlt oder ist ein Symlink: ${SECRET_DIR}"
[[ -f "$SECRET_FILE" && ! -L "$SECRET_FILE" ]] ||
  fail "Secret-Datei fehlt oder ist keine reguläre Datei: ${SECRET_FILE}"
[[ -s "$SECRET_FILE" ]] || fail "Secret-Datei ist leer: ${SECRET_FILE}"

PROTECTED_DIR_MODE="$(stat -c '%a' -- "$SECRET_DIR")" ||
  fail "Modus des Secret-Verzeichnisses konnte nicht geprüft werden."
readonly PROTECTED_DIR_MODE
[[ "$PROTECTED_DIR_MODE" == "700" ]] ||
  fail "Secret-Verzeichnis muss den Modus 0700 haben: ${SECRET_DIR}"
PROTECTED_FILE_MODE="$(stat -c '%a' -- "$SECRET_FILE")" ||
  fail "Modus der Secret-Datei konnte nicht geprüft werden."
readonly PROTECTED_FILE_MODE
[[ "$PROTECTED_FILE_MODE" == "600" ]] ||
  fail "Secret-Datei muss den Modus 0600 haben: ${SECRET_FILE}"
PROTECTED_DIR_OWNER="$(stat -c '%u:%g' -- "$SECRET_DIR")" ||
  fail "Eigentümer des Secret-Verzeichnisses konnte nicht geprüft werden."
readonly PROTECTED_DIR_OWNER
PROTECTED_FILE_OWNER="$(stat -c '%u:%g' -- "$SECRET_FILE")" ||
  fail "Eigentümer der Secret-Datei konnte nicht geprüft werden."
readonly PROTECTED_FILE_OWNER
[[ "$PROTECTED_FILE_OWNER" == "$PROTECTED_DIR_OWNER" ]] ||
  fail "Secret-Verzeichnis und Secret-Datei müssen demselben lokalen Administrationsmodell gehören."

command -v docker >/dev/null 2>&1 || fail "Docker ist nicht verfügbar."
docker info >/dev/null 2>&1 || fail "Der Docker-Daemon ist nicht erreichbar."
docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 ||
  fail "Container fehlt: ${CONTAINER_NAME}"

IMAGE="$(docker inspect --format '{{.Config.Image}}' "$CONTAINER_NAME")"
readonly IMAGE
[[ -n "$IMAGE" ]] || fail "Das Container-Image konnte nicht ermittelt werden."
docker image inspect "$IMAGE" >/dev/null 2>&1 ||
  fail "Hilfsimage ist lokal nicht vorhanden: ${IMAGE}"
[[ -f "$VERIFY_SCRIPT" && -x "$VERIFY_SCRIPT" ]] ||
  fail "Backup-Verifikation fehlt oder ist nicht ausführbar: ${VERIFY_SCRIPT}"

if [[ -e "$BACKUP_DIR" ]]; then
  [[ -d "$BACKUP_DIR" && ! -L "$BACKUP_DIR" ]] ||
    fail "Backupziel existiert, ist aber kein reguläres Verzeichnis: ${BACKUP_DIR}"
else
  mkdir -p -- "$BACKUP_DIR"
fi
chmod 0700 "$BACKUP_DIR"

if ! mkdir -- "$LOCK_DIR" 2>/dev/null; then
  fail "Ein Backup läuft bereits (Lock: ${LOCK_DIR})."
fi
lock_acquired=true

[[ ! -e "$ARCHIVE_PATH" && ! -L "$ARCHIVE_PATH" ]] ||
  fail "Archivziel existiert bereits und wird nicht überschrieben: ${ARCHIVE_PATH}"
[[ ! -e "$CHECKSUM_PATH" && ! -L "$CHECKSUM_PATH" ]] ||
  fail "Prüfsummenziel existiert bereits und wird nicht überschrieben: ${CHECKSUM_PATH}"
[[ ! -e "$MANIFEST_PATH" && ! -L "$MANIFEST_PATH" ]] ||
  fail "Manifestziel existiert bereits und wird nicht überschrieben: ${MANIFEST_PATH}"

mkdir -- "$STAGE_DIR"
chmod 0700 "$STAGE_DIR"
PROTECTED_STAGE_DIR="$(mktemp -d /tmp/codeserver-secret-stage.XXXXXX)" ||
  fail "Temporäres Secret-Staging-Verzeichnis konnte nicht erstellt werden."
chmod 0700 "$PROTECTED_STAGE_DIR"

CONTAINER_STATUS="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME")"
readonly CONTAINER_STATUS
if [[ "$CONTAINER_STATUS" == "running" ]]; then
  container_was_running=true
fi

rsync_stage() {
  docker run --rm \
    --entrypoint /bin/bash \
    --user 0:0 \
    --volume "${SOURCE_DIR}:/source:ro" \
    --volume "${STAGE_DIR}:/stage" \
    "$IMAGE" \
    -c 'rsync -aH --numeric-ids --delete \
      --exclude="node_modules/" \
      --exclude="/.codex/tmp/" \
      --exclude=".cache/" \
      --exclude=".npm/" \
      --exclude=".pnpm-store/" \
      /source/ /stage/'
}

if [[ "$container_was_running" == true ]]; then
  log "Erstelle erste Arbeitskopie bei laufendem Container ..."
  rsync_stage
  log "Stoppe ${CONTAINER_NAME} (Timeout: 30 Sekunden) ..."
  container_stopped=true
  docker stop --time 30 "$CONTAINER_NAME" >/dev/null
  log "Führe finalen rsync-Abgleich durch ..."
  rsync_stage
  log "Starte ${CONTAINER_NAME} sofort wieder ..."
  docker start "$CONTAINER_NAME" >/dev/null
  container_stopped=false
else
  log "Containerstatus ist '${CONTAINER_STATUS}'; erstelle Arbeitskopie ohne Statusänderung ..."
  rsync_stage
fi

readonly STAGED_SECRET_DIR="${PROTECTED_STAGE_DIR}/secrets"
readonly STAGED_SECRET_FILE="${STAGED_SECRET_DIR}/hashed_password"
[[ ! -e "${STAGE_DIR}/secrets" && ! -L "${STAGE_DIR}/secrets" ]] ||
  fail "Reservierter Archivpfad ist bereits im persistenten Verzeichnis belegt: secrets/"
mkdir -- "$STAGED_SECRET_DIR"
chmod 0700 "$STAGED_SECRET_DIR"
cp -p -- "$SECRET_FILE" "$STAGED_SECRET_FILE"
chmod 0600 "$STAGED_SECRET_FILE"
[[ -f "$STAGED_SECRET_FILE" && ! -L "$STAGED_SECRET_FILE" && -s "$STAGED_SECRET_FILE" ]] ||
  fail "Secret-Datei konnte nicht sicher in die Arbeitskopie übernommen werden."
[[ "$(stat -c '%a' -- "$STAGED_SECRET_FILE")" == "600" ]] ||
  fail "Secret-Datei hat in der Arbeitskopie nicht den Modus 0600."

log "Komprimiere Arbeitskopie bei laufendem beziehungsweise unverändertem Container ..."
docker run --rm \
  --entrypoint /bin/bash \
  --user 0:0 \
  --volume "${STAGE_DIR}:/stage:ro" \
  --volume "${PROTECTED_STAGE_DIR}:/secret-stage:ro" \
  --volume "${BACKUP_DIR}:/backup" \
  "$IMAGE" \
  -c 'tar -C /stage -czf "/backup/$1" . -C /secret-stage ./secrets/hashed_password' _ "$ARCHIVE_NAME"

read -r SHA256 _ < <(sha256sum "$ARCHIVE_PATH")
readonly SHA256
printf '%s  %s\n' "$SHA256" "$ARCHIVE_NAME" >"$CHECKSUM_PATH"
ARCHIVE_SIZE="$(wc -c <"$ARCHIVE_PATH")"
readonly ARCHIVE_SIZE
cat >"$MANIFEST_PATH" <<EOF
Erstellungszeitpunkt: $(date '+%Y-%m-%dT%H:%M:%S%z')
Hostname: $(hostname)
Quellverzeichnis: ${SOURCE_DIR}
Secret-Verzeichnis: ${SECRET_DIR}
Secret-Datei im Archiv: secrets/hashed_password
Archivname: ${ARCHIVE_NAME}
Archivgroesse (Bytes): ${ARCHIVE_SIZE}
Containername: ${CONTAINER_NAME}
Container-Image: ${IMAGE}
Containerstatus vor dem Backup: ${CONTAINER_STATUS}
SHA-256: ${SHA256}
EOF
chmod 0600 "$ARCHIVE_PATH" "$CHECKSUM_PATH" "$MANIFEST_PATH"

if ! "$VERIFY_SCRIPT" "$ARCHIVE_PATH"; then
  fail "Neues Backup wurde von verify-backup.sh abgelehnt; Archiv und Sidecar-Dateien bleiben zur Diagnose erhalten: ${ARCHIVE_PATH}"
fi

log "Backup erfolgreich: ${ARCHIVE_PATH}"
log "SHA-256: ${SHA256}"
