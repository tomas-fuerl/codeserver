#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
readonly repo_root
readonly verifier="$repo_root/scripts/verify-backup.sh"
test_root="$(mktemp -d /tmp/codeserver-backup-verifier-test.XXXXXX)"
readonly test_root
readonly output_dir="$test_root/output"
readonly fixture_secret="synthetic-verifier-secret"

cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

fail() {
  printf '[backup-verifier-test] FEHLER: %s\n' "$*" >&2
  exit 1
}

write_checksum() {
  local archive="$1"
  local checksum=""

  read -r checksum _ < <(sha256sum -- "$archive")
  printf '%s  %s\n' "$checksum" "$(basename -- "$archive")" >"${archive}.sha256"
}

create_archive() {
  local archive="$1"
  local secret_mode="$2"
  local fixture_dir=""

  fixture_dir="$(mktemp -d "$test_root/fixture.XXXXXX")"
  mkdir -p -- "$fixture_dir/workspace" "$fixture_dir/data" "$fixture_dir/.codex" "$fixture_dir/secrets"
  printf 'workspace fixture\n' >"$fixture_dir/workspace/example.txt"
  printf 'data fixture\n' >"$fixture_dir/data/example.txt"
  printf 'codex fixture\n' >"$fixture_dir/.codex/example.txt"
  printf '%s\n' "$fixture_secret" >"$fixture_dir/secrets/hashed_password"
  chmod "$secret_mode" "$fixture_dir/secrets/hashed_password"
  tar -C "$fixture_dir" -czf "$archive" .
  write_checksum "$archive"
}

expect_success() {
  local name="$1"
  shift

  if ! "$@" >"$output_dir/${name}.log" 2>&1; then
    fail "Erwarteter Erfolgsfall fehlgeschlagen: ${name}"
  fi
}

expect_failure() {
  local name="$1"
  local expected_message="$2"
  shift 2

  if "$@" >"$output_dir/${name}.log" 2>&1; then
    fail "Erwarteter Fehlerfall war erfolgreich: ${name}"
  fi
  grep -Fq -- "$expected_message" "$output_dir/${name}.log" ||
    fail "Erwartete Fehlermeldung fehlt: ${name}"
}

assert_old_sentinels_absent() {
  local sentinel=""

  for sentinel in 'readonly BACKUP_DIR="/example/path"' 'secret_file_count=CHANGE_ME' 'mktemp /tmp/codeserver.example.com'; do
    if grep -Fq -- "$sentinel" "$verifier"; then
      fail "Alter Publication-Sentinel ist weiterhin vorhanden."
    fi
  done
}

mkdir -- "$output_dir"

explicit_archive="$test_root/explicit.tar.gz"
create_archive "$explicit_archive" 0600
expect_success explicit env -u CODESERVER_BACKUP_ROOT "$verifier" "$explicit_archive"

backup_root="$test_root/backups"
mkdir -- "$backup_root"
older_archive="$backup_root/codeserver-config-20260722-000000.tar.gz"
newer_archive="$backup_root/codeserver-config-20260722-010000.tar.gz"
cp -- "$explicit_archive" "$older_archive"
printf '%064d  %s\n' 0 "$(basename -- "$older_archive")" >"${older_archive}.sha256"
cp -- "$explicit_archive" "$newer_archive"
write_checksum "$newer_archive"
expect_success automatic env CODESERVER_BACKUP_ROOT="$backup_root" "$verifier"

bad_checksum_archive="$test_root/bad-checksum.tar.gz"
cp -- "$explicit_archive" "$bad_checksum_archive"
printf '%064d  %s\n' 0 "$(basename -- "$bad_checksum_archive")" >"${bad_checksum_archive}.sha256"
expect_failure bad-checksum "SHA-256-Prüfung fehlgeschlagen" "$verifier" "$bad_checksum_archive"

wrong_mode_archive="$test_root/wrong-secret-mode.tar.gz"
create_archive "$wrong_mode_archive" 0644
expect_failure wrong-secret-mode "nicht den Modus 0600" "$verifier" "$wrong_mode_archive"

assert_old_sentinels_absent
if grep -FRq -- "$fixture_secret" "$output_dir"; then
  fail "Der Inhalt der synthetischen Secret-Datei wurde ausgegeben."
fi

printf '[backup-verifier-test] ERFOLG: explizite Prüfung, automatische Suche und negative Sicherheitsfälle bestanden.\n'
