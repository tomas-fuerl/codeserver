#!/usr/bin/env bash
# Compose-Ausdrücke werden in den statischen Sollzeilen absichtlich nicht expandiert.
# shellcheck disable=SC2016
set -Eeuo pipefail

umask 077

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"
readonly SCRIPT_DIR
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly COMPOSE_FILE="${REPOSITORY_ROOT}/compose.yaml"
readonly EXAMPLE_ENV_FILE="${REPOSITORY_ROOT}/.env.example"

FAIL_COUNT=0
WARN_COUNT=0

pass() {
  printf 'PASS: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*"
  ((WARN_COUNT += 1))
}

fail_check() {
  printf 'FAIL: %s\n' "$*" >&2
  ((FAIL_COUNT += 1))
}

finish() {
  printf '\nErgebnis: %d FAIL, %d WARN\n' "$FAIL_COUNT" "$WARN_COUNT"
  (( FAIL_COUNT == 0 ))
}

usage() {
  printf 'Aufruf: %s [--static|--runtime|--all]\n' "$0" >&2
  exit 2
}

require_file() {
  local relative_path="$1"

  if [[ -f "${REPOSITORY_ROOT}/${relative_path}" ]]; then
    pass "Repository-Datei vorhanden: ${relative_path}"
  else
    fail_check "Repository-Datei fehlt: ${relative_path}"
  fi
}

require_exact_line() {
  local description="$1"
  local expected="$2"
  local file="$3"

  if grep -Fqx -- "$expected" "$file"; then
    pass "$description"
  else
    fail_check "$description"
  fi
}

validate_absolute_root() {
  local path="$1"

  [[ "$path" == /* && "$path" != "/" &&
    "$path" != */ && "$path" != *"//"* &&
    "/${path#/}/" != *"/./"* && "/${path#/}/" != *"/../"* ]]
}

paths_overlap() {
  local first="$1"
  local second="$2"

  [[ "$first" == "$second" || "$first" == "$second"/* || "$second" == "$first"/* ]]
}

run_static_checks() {
  local required_files=(
    Dockerfile
    compose.yaml
    .env.example
    .trivyignore.yaml
    README.md
    docs/ARCHITECTURE.md
    docs/BACKUP-RESTORE.md
    docs/CONFIGURATION.md
    docs/REPOSITORY-LAYOUT.md
    docs/SYNOLOGY-PORTAINER.md
    docs/UPDATE-ROLLBACK.md
    scripts/backup-config.sh
    scripts/restore-config.sh
    scripts/verify-backup.sh
    scripts/verify-installation.sh
    scripts/ci/run-trivy-scan.sh
    scripts/security/publication-audit.sh
  )
  local relative_path=""
  local file=""
  local script=""
  local shell_script_count=0
  local shell_syntax_failed=false
  local stack_environment_name="stack"".env"
  local forbidden_files=()
  local compose_files=()
  local expected_example_variables=(
    CODESERVER_IMAGE_REPOSITORY
    CODESERVER_IMAGE_TAG
    CODESERVER_CONTAINER_NAME
    CODESERVER_BIND_ADDRESS
    CODESERVER_HOST_PORT
    CODESERVER_CONFIG_PATH
    CODESERVER_SECRET_FILE
    CODESERVER_BACKUP_PATH
    CODESERVER_RESTORE_PATH
    PUID
    PGID
    TZ
    PROXY_DOMAIN
  )
  local expected_compose_variables=(
    CODESERVER_BIND_ADDRESS
    CODESERVER_CONFIG_PATH
    CODESERVER_CONTAINER_NAME
    CODESERVER_HOST_PORT
    CODESERVER_IMAGE_REPOSITORY
    CODESERVER_IMAGE_TAG
    CODESERVER_SECRET_FILE
    PGID
    PROXY_DOMAIN
    PUID
    TZ
  )
  local actual_example_variables=()
  local actual_compose_variables=()
  local expected_text=""
  local actual_text=""
  local legacy_patterns=(
    "docker-compose"".yaml"
    "docker-compose"".ghcr.yaml"
    "Homelab""/codeserver"
    "/config/workspace/""Homelab"
    "tomas-fuerl/""Homelab"
    "homelab-code-""server"
    "deploy-update"".sh"
    "rollback-update"".sh"
  )
  local pattern=""
  local legacy_found=false
  local ports_count=""
  local volumes_count=""

  printf 'Statischer Prüfmodus (kein Docker-Daemon)\n'

  for relative_path in "${required_files[@]}"; do
    require_file "$relative_path"
  done

  mapfile -d '' compose_files < <(
    find "$REPOSITORY_ROOT" -maxdepth 1 -type f \
      \( -iname '*compose*.yaml' -o -iname '*compose*.yml' \) -print0
  )
  if (( ${#compose_files[@]} == 1 )) &&
    [[ "${compose_files[0]}" == "$COMPOSE_FILE" ]]; then
    pass "Genau eine Compose-Datei ist vorhanden: compose.yaml"
  else
    fail_check "Es muss genau eine Compose-Datei namens compose.yaml vorhanden sein."
  fi

  mapfile -d '' forbidden_files < <(
    find "$REPOSITORY_ROOT" -path "$REPOSITORY_ROOT/.git" -prune -o \
      -type f \
      \( -name .env -o -name "$stack_environment_name" \) -print0
  )
  if (( ${#forbidden_files[@]} == 0 )); then
    pass "Keine produktive Environment-Datei im Repository gefunden."
  else
    fail_check "Eine produktive Environment-Datei ist im Repository vorhanden."
  fi

  if python3 - "$REPOSITORY_ROOT" <<'PY'
from __future__ import annotations

import re
import stat
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def is_git_metadata(path: Path, repository_root: Path) -> bool:
    try:
        relative = path.relative_to(repository_root)
    except ValueError:
        return False

    return bool(relative.parts and relative.parts[0] == ".git")


dockerfile_path = root / "Dockerfile"
dockerfile_bytes = dockerfile_path.read_bytes()
dockerfile = dockerfile_bytes.decode("utf-8")
from_lines = [line for line in dockerfile.splitlines() if re.match(r"^FROM\s", line)]
require(len(from_lines) == 1, "Dockerfile muss genau eine FROM-Anweisung enthalten")
if len(from_lines) == 1:
    require(
        re.fullmatch(
            r"FROM lscr[.]io/linuxserver/code-server:[A-Za-z0-9][A-Za-z0-9._-]*@sha256:[0-9a-f]{64}",
            from_lines[0],
        ) is not None,
        "Dockerfile-Basis ist nicht versioniert und digestgepinnt",
    )
    require(":latest" not in from_lines[0].lower(), "Dockerfile-Basis verwendet latest")
require(
    dockerfile.count(
        "LABEL org.opencontainers.image.source=\"https://github.com/tomas-fuerl/codeserver\""
    ) == 1,
    "Öffentliches OCI-Source-Label fehlt oder ist nicht eindeutig",
)
require(
    re.search(r"^\s*(COPY|ADD)\s", dockerfile, re.IGNORECASE | re.MULTILINE) is None,
    "Dockerfile darf keine COPY- oder ADD-Anweisung enthalten",
)
for blocked_reference in (
    "ghcr.io/example",
    "codeserver.example.com",
    "homelab-codeserver",
    "tomas-fuerl/" "Homelab",
    "/config/workspace/" "Homelab",
):
    require(blocked_reference.lower() not in dockerfile.lower(), "Dockerfile enthält eine private oder Beispielreferenz")
for required_reference in (
    "ARG NODE_VERSION=24.18.1",
    "ARG GH_VERSION=2.97.0",
    "GH_CHECKSUMS_SHA256=\"61905c69ec8660f310814ec98395cdd0c2d07aabf024c597ec45813984a02334\"",
    "ARG PNPM_VERSION=11.19.0",
    "PNPM_SHA512=7881f3ed590d472c4a955e2b88b2121791116066dcc88cbca3849ec9b60f1bbaa6d2ccb221fa91da4e1c65bef2bcbe379365aea7ac539c7bf86dedc3a1b22dce",
    "ARG PG_CLIENT_VERSION=18.4-1.pgdg24.04+1",
    "ARG DOCKER_CLI_VERSION=5:29.7.0-1~ubuntu.24.04~noble",
    "ARG DOCKER_COMPOSE_VERSION=5.3.1-1~ubuntu.24.04~noble",
    "ARG DOCKER_BUILDX_VERSION=0.36.0-1~ubuntu.24.04~noble",
    "ARG TRIVY_VERSION=0.72.0",
    "ARG POWERSHELL_VERSION=7.6.4",
    "ARG CODEX_VERSION=\"0.146.0\"",
    "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}",
    "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt",
    "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/${PWSH_ARCHIVE}",
    "amd64) GH_ARCH=\"amd64\" ;;",
    "arm64) GH_ARCH=\"arm64\" ;;",
    "GH_ARCHIVE=\"gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz\"",
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCHIVE}",
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_CHECKSUMS}",
    "/opt/github-cli/${GH_VERSION}/bin/gh",
    "command -v gh",
    "gh --version",
    "pnpm@${PNPM_VERSION}",
    "@openai/codex@${CODEX_VERSION}",
    "https://www.postgresql.org/media/keys/ACCC4CF8.asc",
    "https://apt.postgresql.org/pub/repos/apt",
    "https://download.docker.com/linux/ubuntu/gpg",
    "https://download.docker.com/linux/ubuntu",
    "Signed-By: /etc/apt/keyrings/apt.postgresql.org.asc",
    "Signed-By: /etc/apt/keyrings/docker.asc",
    "PGDG_FINGERPRINT=\"B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8\"",
    "DOCKER_FINGERPRINT=\"9DC858229FC7DD38854AE2D88D81803C0EBFCD88\"",
    "pnpm-${PNPM_VERSION}.tgz",
    "sha512sum --check --strict",
    "TRIVY_CHECKSUMS_SHA256=ebe9d19a774b950e240b1017a038e9b5a002ea068e02023369ff6d241c10c580",
    "TRIVY_AMD64_SHA256=bbb64b9695866ce4a7a8f5c9592002c5961cab378577fa3f8a040df362b9b2ea",
    "TRIVY_ARM64_SHA256=2ca2c023109c2db6b2b77366b6717291452d4531167377d95c79547f0c8e3467",
    "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_ARCHIVE}",
    "ENV TRIVY_CACHE_DIR=/config/.cache/trivy",
    "command -v psql",
    "command -v pg_isready",
    "command -v pg_dump",
    "command -v pg_restore",
    "command -v docker",
    "docker compose version",
    "docker buildx version",
    "command -v trivy",
    "test ! -S /var/run/docker.sock",
    "! command -v dockerd",
    "! command -v containerd",
):
    require(required_reference in dockerfile, "Dockerfile-Werkzeugversion oder offizielle Quelle fehlt")
require(
    dockerfile.count("ENV GH_TELEMETRY=false") == 1,
    "GitHub-CLI-Telemetrie muss im Image exakt einmal deaktiviert sein",
)
require(
    dockerfile.count("sha256sum --check --strict") >= 4,
    "Dockerfile-Prüfsummenprüfungen fehlen",
)
require(
    re.search(r"^\s*gh\s*\\?$", dockerfile, re.MULTILINE) is None,
    "GitHub CLI darf nicht über apt installiert werden",
)
require(
    re.search(r"^\s*(docker-ce|docker.io|dockerd|containerd|containerd.io)\s*", dockerfile, re.MULTILINE) is None,
    "Dockerfile darf keine Docker-Daemonpakete installieren",
)
require(
    "apt-key" not in dockerfile,
    "Dockerfile darf apt-key nicht verwenden",
)
require(
    re.search(r"^\s*ENV TRIVY_CACHE_DIR=/config/\.cache/trivy$", dockerfile, re.MULTILINE) is not None,
    "Trivy-Cache muss unterhalb von /config liegen",
)
ignore_file = root / ".trivyignore.yaml"
require(ignore_file.is_file(), "Trivy-Ausnahmedatei fehlt")
if ignore_file.is_file():
    ignore_text = ignore_file.read_text(encoding="utf-8")
    require(ignore_text.count("misconfigurations:") == 1, "Trivy-Ausnahme muss genau einen Misconfiguration-Block enthalten")
    require(ignore_text.count("- id: AVD-DS-0002") == 1, "Trivy-Ausnahme muss genau AVD-DS-0002 enthalten")
    require(ignore_text.count("expired_at: 2026-10-31") == 1, "Trivy-Ausnahme muss exakt am 2026-10-31 ablaufen")
    require("CVE-" not in ignore_text and "GHSA-" not in ignore_text and "*" not in ignore_text, "Trivy-Ausnahme darf keine CVE/GHSA/Wildcard-Regel enthalten")
    require("--ignorefile" in (root / "scripts/ci/run-trivy-scan.sh").read_text(encoding="utf-8"), "Trivy-Scanner muss die Ausnahme explizit verwenden")

publication_audit = root / "scripts/security/publication-audit.sh"
require(
    publication_audit.is_file() and stat.S_IMODE(publication_audit.stat().st_mode) == 0o755,
    "Publication-Audit muss Modus 0755 besitzen",
)
for shell_script in root.rglob("*.sh"):
    if is_git_metadata(shell_script, root):
        continue
    require(shell_script.stat().st_mode & 0o111 != 0, "Mindestens ein Shellskript ist nicht ausführbar")
for candidate in root.rglob("*"):
    if is_git_metadata(candidate, root):
        continue
    if not candidate.is_file() or candidate.is_symlink():
        continue
    contents = candidate.read_bytes()
    if contents and b"\0" not in contents:
        require(contents.endswith(b"\n"), "Mindestens eine Textdatei endet nicht mit LF")

desired_pattern = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]*[.][A-Za-z0-9][A-Za-z0-9-]*")
lock_pattern = re.compile(
    r"([A-Za-z0-9][A-Za-z0-9-]*[.][A-Za-z0-9][A-Za-z0-9-]*)@([A-Za-z0-9][A-Za-z0-9._+-]*)"
)
desired_lines: list[str] = []
for raw_line in (root / "extensions.txt").read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    require(line == raw_line and desired_pattern.fullmatch(line) is not None, "Ungültiger Eintrag in extensions.txt")
    desired_lines.append(line.lower())
require(len(desired_lines) == len(set(desired_lines)), "Doppelte Extension-ID in extensions.txt")

lock_lines = (root / "extensions.lock.txt").read_text(encoding="utf-8").splitlines()
require(len(lock_lines) == 9, "extensions.lock.txt muss exakt neun Einträge enthalten")
lock_ids: list[str] = []
for line in lock_lines:
    match = lock_pattern.fullmatch(line)
    require(match is not None, "Ungültige oder ungepinnte Zeile in extensions.lock.txt")
    if match is not None:
        lock_ids.append(match.group(1).lower())
require(len(lock_ids) == len(set(lock_ids)), "Doppelte Extension-ID in extensions.lock.txt")
lock_counts = Counter(lock_ids)
for desired_id in desired_lines:
    require(lock_counts[desired_id] == 1, "Gewünschte Extension fehlt oder ist im Lock nicht eindeutig")

sync_script = (root / "scripts/sync-extensions.sh").read_text(encoding="utf-8")
for required_fragment in (
    "CODESERVER_EXTENSIONS_LOCK_FILE",
    "LOCK_FILE=\"$REPOSITORY_ROOT/extensions.lock.txt\"",
    "[[ \"$LOCK_FILE\" != /* ]]",
    "done < \"$LOCK_FILE\"",
    "code-server --install-extension \"$extension\"",
):
    require(required_fragment in sync_script, "sync-extensions.sh verletzt den Root-Lockvertrag")
for blocked_fragment in ("codeserver.example.com", "extensions.example.com", "/config/workspace/" "Homelab"):
    require(blocked_fragment not in sync_script, "sync-extensions.sh enthält einen Beispiel- oder Privatpfad")

if errors:
    for error in sorted(set(errors)):
        print(f"MIG-006-Vertragsprüfung fehlgeschlagen: {error}", file=sys.stderr)
    raise SystemExit(1)
print("MIG-006 Dockerfile-, Modus-, Text- und Extensionverträge bestanden.")
PY
  then
    pass "MIG-006 Dockerfile-, Modus-, Text- und Extensionverträge."
  else
    fail_check "MIG-006 Dockerfile-, Modus-, Text- oder Extensionvertrag verletzt."
  fi

  while IFS= read -r -d '' file; do
    relative_path="${file#"${REPOSITORY_ROOT}/"}"
    case "$relative_path" in
      docs/migration/*|.gitignore|scripts/security/publication-audit.sh)
        continue
        ;;
    esac
    for pattern in "${legacy_patterns[@]}"; do
      if grep -Fq -- "$pattern" "$file"; then
        legacy_found=true
      fi
    done
  done < <(
    find "$REPOSITORY_ROOT" -path "$REPOSITORY_ROOT/.git" -prune -o \
      -type f -print0
  )
  if [[ "$legacy_found" == false ]]; then
    pass "Keine aktiven Legacy-Verweise außerhalb historischer Migrationsdokumentation."
  else
    fail_check "Aktive Legacy-Verweise außerhalb historischer Migrationsdokumentation gefunden."
  fi

  mapfile -t actual_example_variables < <(
    sed -n 's/^\([A-Z][A-Z0-9_]*\)=\(.*\)$/\1/p' "$EXAMPLE_ENV_FILE"
  )
  expected_text="$(printf '%s\n' "${expected_example_variables[@]}")"
  actual_text="$(printf '%s\n' "${actual_example_variables[@]}")"
  if [[ "$actual_text" == "$expected_text" ]]; then
    pass ".env.example enthält exakt den kanonischen Variablensatz."
  else
    fail_check ".env.example weicht vom kanonischen Variablensatz ab."
  fi

  mapfile -t actual_compose_variables < <(
    grep -oE '\$\{[A-Z][A-Z0-9_]*' "$COMPOSE_FILE" |
      sed 's/^${//' |
      sort -u
  )
  expected_text="$(printf '%s\n' "${expected_compose_variables[@]}")"
  actual_text="$(printf '%s\n' "${actual_compose_variables[@]}")"
  if [[ "$actual_text" == "$expected_text" ]]; then
    pass "Compose verwendet exakt den dokumentierten Compose-Variablensatz."
  else
    fail_check "Compose-Variablen weichen vom dokumentierten Vertrag ab."
  fi

  require_exact_line \
    "Compose verwendet das öffentliche GHCR-Repository und einen verpflichtenden expliziten Tag." \
    '    image: "${CODESERVER_IMAGE_REPOSITORY:-ghcr.io/tomas-fuerl/codeserver}:${CODESERVER_IMAGE_TAG:?CODESERVER_IMAGE_TAG must be set}"' \
    "$COMPOSE_FILE"
  require_exact_line \
    "Compose verwendet den kanonischen Containername-Default." \
    '    container_name: "${CODESERVER_CONTAINER_NAME:-codeserver}"' \
    "$COMPOSE_FILE"
  require_exact_line \
    "Compose verwendet die Loopback-Portbindung mit Defaultport 8377." \
    '      - "${CODESERVER_BIND_ADDRESS:-127.0.0.1}:${CODESERVER_HOST_PORT:-8377}:8443"' \
    "$COMPOSE_FILE"
  require_exact_line \
    "Compose bindet den Configpfad auf /config." \
    '      - "${CODESERVER_CONFIG_PATH:?CODESERVER_CONFIG_PATH must be set}:/config"' \
    "$COMPOSE_FILE"
  require_exact_line \
    "Compose bindet die Secret-Datei read-only ein." \
    '      - "${CODESERVER_SECRET_FILE:?CODESERVER_SECRET_FILE must be set}:/run/secrets/hashed_password:ro"' \
    "$COMPOSE_FILE"
  require_exact_line \
    "FILE__HASHED_PASSWORD verweist fest auf den gemounteten Secret-Pfad." \
    '      FILE__HASHED_PASSWORD: "/run/secrets/hashed_password" # public example' \
    "$COMPOSE_FILE"

  ports_count="$(
    awk '
      /^    ports:[[:space:]]*$/ { active = 1; next }
      active && /^    [[:alnum:]_-]+:/ { active = 0 }
      active && /^      - / { count += 1 }
      END { print count + 0 }
    ' "$COMPOSE_FILE"
  )"
  if [[ "$ports_count" == "1" ]]; then
    pass "Compose veröffentlicht genau einen Port."
  else
    fail_check "Compose muss genau einen Port veröffentlichen."
  fi

  volumes_count="$(
    awk '
      /^    volumes:[[:space:]]*$/ { active = 1; next }
      active && /^    [[:alnum:]_-]+:/ { active = 0 }
      active && /^      - / { count += 1 }
      END { print count + 0 }
    ' "$COMPOSE_FILE"
  )"
  if [[ "$volumes_count" == "2" ]]; then
    pass "Compose enthält genau Config- und Secret-Mount."
  else
    fail_check "Compose muss genau zwei Mounts enthalten."
  fi

  if grep -Eq '^[[:space:]]+(build|pull_policy):' "$COMPOSE_FILE" ||
    grep -Fq -- "latest" "$COMPOSE_FILE"; then
    fail_check "Compose enthält einen Build-, Pull-Always- oder Latest-Vertrag."
  else
    pass "Compose enthält weder Build noch Pull-Always noch latest."
  fi

  if grep -Eq '^[[:space:]]+(PASSWORD|HASHED_PASSWORD|SUDO_PASSWORD|FILE__PASSWORD):' \
    "$COMPOSE_FILE"; then
    fail_check "Compose enthält eine unzulässige Klartextpasswortvariable."
  else
    pass "Compose enthält keine Klartextpasswortvariable."
  fi

  if grep -Fq -- "http://127.0.0.1:8443/healthz" "$COMPOSE_FILE" &&
    grep -Eq '^[[:space:]]+restart:[[:space:]]+unless-stopped[[:space:]]*$' "$COMPOSE_FILE" &&
    grep -Eq '^[[:space:]]+stop_grace_period:[[:space:]]+30s[[:space:]]*$' "$COMPOSE_FILE" &&
    grep -Fq -- 'max-size: "10m"' "$COMPOSE_FILE" &&
    grep -Fq -- 'max-file: "3"' "$COMPOSE_FILE"; then
    pass "Healthcheck, Restart, Stop-Grace-Period und Logbegrenzung sind vorhanden."
  else
    fail_check "Betriebsparameter oder funktionaler lokaler Healthcheck fehlen."
  fi

  while IFS= read -r -d '' script; do
    ((shell_script_count += 1))
    if ! bash -n "$script"; then
      shell_syntax_failed=true
      fail_check "Shellsyntax fehlerhaft: ${script#"${REPOSITORY_ROOT}/"}"
    fi
  done < <(
    find "$REPOSITORY_ROOT" -path "$REPOSITORY_ROOT/.git" -prune -o \
      -type f -name '*.sh' -print0
  )
  if [[ "$shell_syntax_failed" == false && "$shell_script_count" -gt 0 ]]; then
    pass "bash -n akzeptiert alle ${shell_script_count} Shellskripte."
  fi
}

run_runtime_checks() {
  local container_name="${CODESERVER_CONTAINER_NAME:-CHANGE_ME}"
  local config_root="${CODESERVER_CONFIG_ROOT:-CHANGE_ME}"
  local secret_root="${CODESERVER_SECRET_ROOT:-CHANGE_ME}"
  local backup_root="${CODESERVER_BACKUP_ROOT:-CHANGE_ME}"
  local restore_root="${CODESERVER_RESTORE_ROOT:-CHANGE_ME}"
  local secret_file="${secret_root}/hashed_password"
  local invalid_contract=false
  local path=""
  local running_image=""
  local container_status=""
  local container_health=""
  local published_ports=""
  local mounts=""
  local file_credential_setting=""
  local environment_names=""
  local forbidden_environment_found=false
  local variable_name=""

  printf 'Runtime-Prüfmodus (ausdrücklich angeforderter Docker-Zugriff)\n'

  if [[ -z "$container_name" || "$container_name" == "CHANGE_ME" ||
    -z "$config_root" || "$config_root" == "CHANGE_ME" ||
    -z "$secret_root" || "$secret_root" == "CHANGE_ME" ||
    -z "$backup_root" || "$backup_root" == "CHANGE_ME" ||
    -z "$restore_root" || "$restore_root" == "CHANGE_ME" ]]; then
    fail_check "Alle fünf CODESERVER_*-Runtimevariablen müssen explizit gesetzt sein."
    return
  fi
  [[ "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] ||
    invalid_contract=true
  for path in "$config_root" "$secret_root" "$backup_root" "$restore_root"; do
    if ! validate_absolute_root "$path"; then
      invalid_contract=true
    fi
  done
  if paths_overlap "$config_root" "$secret_root" ||
    paths_overlap "$config_root" "$backup_root" ||
    paths_overlap "$config_root" "$restore_root" ||
    paths_overlap "$secret_root" "$backup_root" ||
    paths_overlap "$secret_root" "$restore_root" ||
    paths_overlap "$backup_root" "$restore_root"; then
    invalid_contract=true
  fi
  if [[ "$invalid_contract" == true ]]; then
    fail_check "Runtimevariablen verletzen Namen-, Absolutpfad- oder Trennungsregeln."
    return
  fi
  pass "Runtimevariablen sind vollständig und lexikalisch sicher."

  if ! command -v docker >/dev/null 2>&1; then
    fail_check "Docker ist auf dem Host nicht verfügbar."
    return
  fi
  if ! docker info >/dev/null 2>&1; then
    fail_check "Der Docker-Daemon ist nicht erreichbar."
    return
  fi
  pass "Docker-Daemon ist für die ausdrückliche Runtimeprüfung erreichbar."

  if ! docker inspect --type container "$container_name" >/dev/null 2>&1; then
    fail_check "Container ${container_name} fehlt."
    return
  fi
  pass "Container ${container_name} ist vorhanden."

  running_image="$(docker inspect --format '{{.Config.Image}}' "$container_name" 2>/dev/null || true)"
  if [[ "$running_image" == ghcr.io/tomas-fuerl/codeserver:* &&
    "${running_image#ghcr.io/tomas-fuerl/codeserver:}" != "latest" &&
    -n "${running_image#ghcr.io/tomas-fuerl/codeserver:}" ]]; then
    pass "Container verwendet ein explizites Image aus ghcr.io/tomas-fuerl/codeserver."
  else
    fail_check "Container verwendet kein erwartetes explizites GHCR-Image."
  fi

  container_status="$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || true)"
  if [[ "$container_status" == "running" ]]; then
    pass "Containerstatus ist running."
  else
    fail_check "Containerstatus ist nicht running."
  fi

  container_health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$container_name" 2>/dev/null || true
  )"
  if [[ "$container_health" == "healthy" ]]; then
    pass "Container-Healthstatus ist healthy."
  else
    fail_check "Container-Healthstatus ist nicht healthy."
  fi

  published_ports="$(
    docker inspect \
      --format '{{range $port, $bindings := .NetworkSettings.Ports}}{{range $bindings}}{{printf "%s|%s|%s\n" $port .HostIp .HostPort}}{{end}}{{end}}' \
      "$container_name" 2>/dev/null || true
  )"
  if [[ "$published_ports" =~ ^8443/tcp\|127\.0\.0\.1\|[0-9]+$ ]]; then
    pass "Port 8443 ist ausschließlich an einen Loopback-Port gebunden."
  else
    fail_check "Veröffentlichte Ports verletzen den Loopback-Vertrag."
  fi

  mounts="$(
    docker inspect \
      --format '{{range .Mounts}}{{printf "%s|%s|%t\n" .Source .Destination .RW}}{{end}}' \
      "$container_name" 2>/dev/null || true
  )"
  if grep -Fxq -- "${config_root}|/config|true" <<<"$mounts"; then
    pass "Erwarteter Config-Mount ist vorhanden."
  else
    fail_check "Erwarteter Config-Mount fehlt."
  fi
  if grep -Fxq -- "${secret_file}|/run/secrets/hashed_password|false" <<<"$mounts"; then
    pass "Erwarteter read-only Secret-Mount ist vorhanden."
  else
    fail_check "Erwarteter read-only Secret-Mount fehlt."
  fi

  file_credential_setting="$(
    docker inspect \
      --format '{{range .Config.Env}}{{if eq . "FILE__HASHED_PASSWORD=/run/secrets/hashed_password"}}present{{end}}{{end}}' \
      "$container_name" 2>/dev/null || true
  )"
  if [[ "$file_credential_setting" == "present" ]]; then
    pass "FILE__HASHED_PASSWORD verweist auf den gemounteten Secret-Pfad."
  else
    fail_check "FILE__HASHED_PASSWORD fehlt oder verweist auf einen unerwarteten Pfad."
  fi

  if environment_names="$(
    docker inspect \
      --format '{{range .Config.Env}}{{println (index (split . "=") 0)}}{{end}}' \
      "$container_name" 2>/dev/null
  )"; then
    for variable_name in PASSWORD HASHED_PASSWORD SUDO_PASSWORD FILE__PASSWORD; do
      if grep -Fxq -- "$variable_name" <<<"$environment_names"; then
        forbidden_environment_found=true
      fi
    done
    if [[ "$forbidden_environment_found" == false ]]; then
      pass "Keine Klartextpasswortvariable ist im Container gesetzt."
    else
      fail_check "Mindestens eine Klartextpasswortvariable ist im Container gesetzt."
    fi
  else
    fail_check "Container-Umgebungsvariablennamen konnten nicht geprüft werden."
  fi

  for path in "$config_root" "$secret_root" "$backup_root" "$restore_root"; do
    if [[ -d "$path" && ! -L "$path" ]]; then
      pass "Lokales Verzeichnis vorhanden und kein Symlink: ${path}"
    else
      fail_check "Lokales Verzeichnis fehlt oder ist ein Symlink: ${path}"
    fi
  done

  if [[ -f "$secret_file" && ! -L "$secret_file" && -s "$secret_file" ]]; then
    pass "Secret-Datei ist regulär und nicht leer."
    if [[ "$(stat -c '%a' -- "$secret_file" 2>/dev/null || true)" == "600" ]]; then
      pass "Secret-Datei hat Modus 0600."
    else
      fail_check "Secret-Datei hat nicht Modus 0600."
    fi
  else
    fail_check "Secret-Datei fehlt, ist leer oder ist kein reguläres File."
  fi
}

mode="${1:---static}"
(( $# <= 1 )) || usage
case "$mode" in
  --static)
    run_static_checks
    ;;
  --runtime)
    run_runtime_checks
    ;;
  --all)
    run_static_checks
    run_runtime_checks
    ;;
  *)
    usage
    ;;
esac

finish
