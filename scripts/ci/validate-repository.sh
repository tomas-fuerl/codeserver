#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"

printf 'Repository root: %s\n' "$repo_root"

printf 'Validating Docker build context allowlist...\n'
python3 - "$repo_root" <<'PY'
from __future__ import annotations

import fnmatch
import json
import re
import shlex
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

repo_root = Path(sys.argv[1])
dockerfile = repo_root / "Dockerfile"
dockerignore = repo_root / ".dockerignore"

if not dockerignore.is_file():
    raise SystemExit("Docker build context validation failed: .dockerignore is missing")
if dockerignore.stat().st_size == 0:
    raise SystemExit("Docker build context validation failed: .dockerignore is empty")

effective_rules = [
    line.strip()
    for line in dockerignore.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
if not effective_rules or effective_rules[0] != "**":
    raise SystemExit(
        "Docker build context validation failed: first effective rule must be **"
    )
if len(effective_rules) != len(set(effective_rules)):
    raise SystemExit("Docker build context validation failed: duplicate rule")
if any(not rule.startswith("!") for rule in effective_rules[1:]):
    raise SystemExit(
        "Docker build context validation failed: rules after ** must be allowlist entries"
    )


def logical_instructions(contents: str) -> list[str]:
    instructions: list[str] = []
    current = ""
    for raw_line in contents.splitlines():
        part = raw_line.rstrip()
        current = f"{current}{part.lstrip()}" if current else part.lstrip()
        if current.endswith("\\"):
            current = f"{current[:-1]} "
            continue
        if current:
            instructions.append(current)
        current = ""
    if current:
        raise SystemExit("Docker build context validation failed: dangling continuation")
    return instructions


def instruction_sources(instruction: str) -> list[tuple[str, str]]:
    match = re.match(r"^(COPY|ADD)\\s+(.+)$", instruction, flags=re.IGNORECASE)
    if not match:
        return []

    kind = match.group(1).upper()
    remainder = match.group(2).strip()
    from_stage = False
    while remainder.startswith("--"):
        option, separator, remainder = remainder.partition(" ")
        if not separator:
            raise SystemExit(
                f"Docker build context validation failed: malformed {kind} option"
            )
        if option.startswith("--from="):
            from_stage = True
        remainder = remainder.lstrip()

    if remainder.startswith("["):
        try:
            operands = json.loads(remainder)
        except json.JSONDecodeError as error:
            raise SystemExit(
                f"Docker build context validation failed: invalid {kind} JSON form"
            ) from error
        if not isinstance(operands, list) or not all(
            isinstance(item, str) for item in operands
        ):
            raise SystemExit(
                f"Docker build context validation failed: invalid {kind} operands"
            )
    else:
        try:
            operands = shlex.split(remainder, comments=False, posix=True)
        except ValueError as error:
            raise SystemExit(
                f"Docker build context validation failed: invalid {kind} shell form"
            ) from error

    if len(operands) < 2:
        raise SystemExit(
            f"Docker build context validation failed: {kind} needs source and destination"
        )
    if from_stage:
        return []
    return [(kind, source) for source in operands[:-1]]


blocked_components = {
    ".git",
    ".github",
    ".publication-audit",
    "docs",
    "secrets",
    ".secrets",
    "backups",
    "restore-tests",
}
blocked_exact_names = {
    ".env",
    "stack.env",
    "TASK.md",
    "TASK-RESULT.md",
    "id_rsa",
    "id_ed25519",
}
blocked_name_patterns = (
    ".env.*",
    "*.log",
    "*.tar",
    "*.tar.gz",
    "*.tgz",
    "*.zip",
    "*.pem",
    "*.key",
    "*.p12",
    "*.pfx",
    "*.kdbx",
)


def validate_local_source(kind: str, source: str) -> PurePosixPath | None:
    if kind == "ADD" and (
        urlsplit(source).scheme in {"http", "https"} or source.startswith("git@")
    ):
        return None
    if source in {".", "./"} or any(character in source for character in "*?["):
        raise SystemExit(
            f"Docker build context validation failed: unbounded {kind} source {source!r}"
        )
    if "$" in source:
        raise SystemExit(
            f"Docker build context validation failed: dynamic {kind} source {source!r}"
        )

    normalized = source.removeprefix("./").rstrip("/")
    local_path = PurePosixPath(normalized)
    if not normalized or local_path.is_absolute() or ".." in local_path.parts:
        raise SystemExit(
            f"Docker build context validation failed: unsafe {kind} source {source!r}"
        )
    if any(part in blocked_components for part in local_path.parts):
        raise SystemExit(
            f"Docker build context validation failed: blocked {kind} source {source!r}"
        )
    if local_path.name in blocked_exact_names or any(
        fnmatch.fnmatchcase(local_path.name, pattern)
        for pattern in blocked_name_patterns
    ):
        raise SystemExit(
            f"Docker build context validation failed: blocked {kind} source {source!r}"
        )
    if not (repo_root / local_path).exists():
        raise SystemExit(
            f"Docker build context validation failed: missing {kind} source {source!r}"
        )
    return local_path


local_sources: set[PurePosixPath] = set()
for instruction in logical_instructions(dockerfile.read_text(encoding="utf-8")):
    for instruction_kind, instruction_source in instruction_sources(instruction):
        local_source = validate_local_source(instruction_kind, instruction_source)
        if local_source is not None:
            local_sources.add(local_source)

required_allowlist = {"!Dockerfile", "!.dockerignore"}
for local_source in sorted(local_sources, key=str):
    source_path = repo_root / local_source
    parents = list(local_source.parents)[:-1]
    for parent in reversed(parents):
        required_allowlist.add(f"!{parent.as_posix()}/")
    if source_path.is_dir():
        required_allowlist.add(f"!{local_source.as_posix()}/")
        for child in sorted(source_path.rglob("*")):
            relative_child = child.relative_to(repo_root).as_posix()
            required_allowlist.add(f"!{relative_child}/" if child.is_dir() else f"!{relative_child}")
    else:
        required_allowlist.add(f"!{local_source.as_posix()}")

actual_allowlist = set(effective_rules[1:])
missing_rules = sorted(required_allowlist - actual_allowlist)
unexpected_rules = sorted(actual_allowlist - required_allowlist)
if missing_rules or unexpected_rules:
    details = []
    if missing_rules:
        details.append(f"missing rules: {', '.join(missing_rules)}")
    if unexpected_rules:
        details.append(f"unexpected rules: {', '.join(unexpected_rules)}")
    raise SystemExit(
        "Docker build context validation failed: " + "; ".join(details)
    )

source_summary = ", ".join(str(source) for source in sorted(local_sources, key=str))
print(
    "Docker build context allowlist passed: "
    f"{len(effective_rules)} effective rules; local inputs: {source_summary or 'none'}."
)
PY

mapfile -d '' -t shell_files < <(
  find "$repo_root" -path "$repo_root/.git" -prune -o \
    -type f -name '*.sh' -print0 | sort -z
)

if (( ${#shell_files[@]} == 0 )); then
  printf 'No Shell scripts found.\n' >&2
  exit 1
fi

printf 'Checking Bash syntax for %d scripts...\n' "${#shell_files[@]}"
for script in "${shell_files[@]}"; do
  bash -n "$script"
done

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'ShellCheck is required.\n' >&2
  exit 1
fi
printf 'Running ShellCheck...\n'
shellcheck "${shell_files[@]}"

printf 'Running backup verifier regression tests...\n'
"$repo_root/scripts/ci/test-backup-verifier.sh"

printf 'Running static installation and MIG-006 freeze-contract verification...\n'
"$repo_root/scripts/verify-installation.sh" --static

printf 'Checking MIG-017 daemonless toolchain contract...\n'
for required_fragment in \
  'ARG PNPM_VERSION=11.4.0' \
  'ARG PG_CLIENT_VERSION=18.4-1.pgdg24.04+1' \
  'ARG DOCKER_CLI_VERSION=5:29.7.0-1~ubuntu.24.04~noble' \
  'ARG DOCKER_COMPOSE_VERSION=5.3.1-1~ubuntu.24.04~noble' \
  'ARG DOCKER_BUILDX_VERSION=0.36.0-1~ubuntu.24.04~noble' \
  'ARG TRIVY_VERSION=0.72.0' \
  'Signed-By: /etc/apt/keyrings/apt.postgresql.org.asc' \
  'Signed-By: /etc/apt/keyrings/docker.asc' \
  'test ! -S /var/run/docker.sock' \
  '! command -v dockerd' \
  '! command -v containerd'; do
  grep -Fq -- "$required_fragment" "$repo_root/Dockerfile" || {
    printf 'Missing Dockerfile contract: %s\n' "$required_fragment" >&2
    exit 1
  }
done
if grep -Eq '^[[:space:]]+(docker-ce|docker.io|dockerd|containerd|containerd.io)[[:space:]]' "$repo_root/Dockerfile"; then
  printf 'Docker daemon package reference found in install contract.\n' >&2
  exit 1
fi
"$repo_root/scripts/ci/run-trivy-scan.sh" --help >/dev/null

printf 'Running publication audit...\n'
(
  cd "$repo_root"
  bash scripts/security/publication-audit.sh --current-tree
)

printf 'Validating Actions contracts...\n'
"$repo_root/scripts/ci/validate-actions.sh"

printf 'Checking relative Markdown links...\n'
python3 "$repo_root/scripts/ci/check-markdown-links.py"

printf 'Checking conflict markers...\n'
if find "$repo_root" -path "$repo_root/.git" -prune -o -type f -print0 |
  xargs -0 grep -nE '^(<<<<<<< |=======|>>>>>>> )'; then
  printf 'Merge conflict marker found.\n' >&2
  exit 1
fi

printf 'Checking prohibited filenames...\n'
prohibited_file="$(find "$repo_root" -path "$repo_root/.git" -prune -o -type f \
  \( -name '.env' -o -name 'stack.env' -o -name '*.pem' -o -name '*.key' \
  -o -name '*.p12' -o -name '*.pfx' -o -name 'id_rsa' -o -name 'id_ed25519' \
  -o -name '*.kdbx' -o -name '*.log' -o -name '*.tar' -o -name '*.tar.gz' \
  -o -name '*.zip' \) -print -quit)"
if [[ -n "$prohibited_file" ]]; then
  printf 'Prohibited file found: %s\n' "${prohibited_file#"$repo_root"/}" >&2
  exit 1
fi

mapfile -d '' -t compose_files < <(
  find "$repo_root" -path "$repo_root/.git" -prune -o \
    -type f -name 'compose.yaml' -print0
)
if (( ${#compose_files[@]} != 1 )) || [[ "${compose_files[0]:-}" != "$repo_root/compose.yaml" ]]; then
  printf 'Expected exactly the root compose.yaml.\n' >&2
  exit 1
fi

legacy_prefix="docker-""compose"
legacy_compose="$(find "$repo_root" -path "$repo_root/.git" -prune -o -type f \
  \( -name "${legacy_prefix}.yml" -o -name "${legacy_prefix}.yaml" \
  -o -name "${legacy_prefix}.*.yml" -o -name "${legacy_prefix}.*.yaml" \
  -o -name 'compose.yml' -o -name 'compose.*.yml' -o -name 'compose.*.yaml' \) \
  -print -quit)"
if [[ -n "$legacy_compose" ]]; then
  printf 'Legacy Compose file found: %s\n' "${legacy_compose#"$repo_root"/}" >&2
  exit 1
fi

nested_git="$(find "$repo_root" -mindepth 2 -name '.git' -print -quit)"
if [[ -n "$nested_git" ]]; then
  printf 'Nested Git metadata found: %s\n' "${nested_git#"$repo_root"/}" >&2
  exit 1
fi

if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'Checking Git whitespace...\n'
  git -C "$repo_root" diff --check
fi

markdown_count="$(find "$repo_root" -path "$repo_root/.git" -prune -o -type f -name '*.md' -print | wc -l)"
printf 'Repository validation passed: %d shell scripts, %s Markdown files, 2 workflows, 1 Compose file.\n' \
  "${#shell_files[@]}" "$markdown_count"
