#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
workflow_dir="$repo_root/.github/workflows"
ci_workflow="$workflow_dir/ci.yml"
publish_workflow="$workflow_dir/publish-image.yml"
dollar="$"
failures=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

require_literal() {
  local file="$1"
  local value="$2"
  local description="$3"
  if ! grep -Fq -- "$value" "$file"; then
    fail "$description"
  fi
}

forbid_regex() {
  local file="$1"
  local expression="$2"
  local description="$3"
  if grep -Eiq -- "$expression" "$file"; then
    fail "$description"
  fi
}

mapfile -d '' -t workflow_files < <(
  find "$workflow_dir" -maxdepth 1 -type f \
    \( -name '*.yml' -o -name '*.yaml' \) -print0 | sort -z
)

if (( ${#workflow_files[@]} != 2 )); then
  fail "expected exactly two workflow files, found ${#workflow_files[@]}"
fi

for expected in "$ci_workflow" "$publish_workflow"; do
  if [[ ! -f "$expected" ]]; then
    fail "missing expected workflow: ${expected#"$repo_root"/}"
  fi
done

if (( failures > 0 )); then
  printf 'Action contract validation failed before content checks.\n' >&2
  exit 1
fi

uses_pattern='^[[:space:]]+uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40} #[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+$'
uses_count=0
while IFS= read -r entry; do
  content="${entry#*:}"
  content="${content#*:}"
  uses_count=$((uses_count + 1))
  if [[ ! "$content" =~ $uses_pattern ]]; then
    fail "unpinned or uncommented uses reference: $entry"
  fi
done < <(grep -nH -E '^[[:space:]]+uses:' "$ci_workflow" "$publish_workflow")

if (( uses_count == 0 )); then
  fail "no Actions references found"
fi

for workflow in "$ci_workflow" "$publish_workflow"; do
  forbid_regex "$workflow" '^[[:space:]]*(pull_request_target|workflow_run|repository_dispatch|schedule):' "forbidden workflow trigger in ${workflow#"$repo_root"/}"
  forbid_regex "$workflow" 'runs-on:[[:space:]]*self-hosted|write-all' "forbidden runner or permission shortcut in ${workflow#"$repo_root"/}"
  forbid_regex "$workflow" 'github\.event|curl[[:space:]].*\|[[:space:]]*(ba)?sh|^[[:space:]]*eval[[:space:]]' "unsafe dynamic workflow code in ${workflow#"$repo_root"/}"
  forbid_regex "$workflow" 'portainer|ssh|deploy(ment)?' "deployment-oriented code in ${workflow#"$repo_root"/}"
done

require_literal "$ci_workflow" '  pull_request:' "CI pull_request trigger missing"
require_literal "$ci_workflow" '  push:' "CI push trigger missing"
require_literal "$ci_workflow" '  workflow_dispatch:' "CI workflow_dispatch trigger missing"
require_literal "$ci_workflow" '      - main' "CI main branch restriction missing"
require_literal "$ci_workflow" 'permissions:' "CI permissions block missing"
require_literal "$ci_workflow" '  contents: read' "CI contents: read permission missing"
require_literal "$ci_workflow" '  validate-and-build:' "CI primary job missing"
require_literal "$ci_workflow" '    runs-on: ubuntu-24.04' "CI runner is not explicit"
require_literal "$ci_workflow" '    timeout-minutes: 90' "CI timeout missing"
require_literal "$ci_workflow" '  cancel-in-progress: true' "CI concurrency cancellation missing"
require_literal "$ci_workflow" '      - name: Set up QEMU' "CI QEMU setup missing"
require_literal "$ci_workflow" '        uses: docker/setup-qemu-action@96fe6ef7f33517b61c61be40b68a1882f3264fb8 # v4.2.0' "CI QEMU action pin missing"
require_literal "$ci_workflow" '        uses: aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567 # v0.3.1' "CI Trivy setup action pin missing"
require_literal "$ci_workflow" '          version: v0.72.0' "CI Trivy binary version pin missing"
require_literal "$ci_workflow" "test \"\$(trivy --version | sed -n '1p')\" = 'Version: 0.72.0'" "CI Trivy exact version check missing"
require_literal "$ci_workflow" '        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v7.0.1' "CI report artifact action pin missing"
require_literal "$ci_workflow" '          platforms: linux/amd64' "CI amd64 build platform missing"
require_literal "$ci_workflow" '          platforms: linux/arm64' "CI arm64 build platform missing"
require_literal "$ci_workflow" '          push: false' "CI build must not push"
require_literal "$ci_workflow" '          provenance: false' "CI provenance setting missing"
require_literal "$ci_workflow" '          sbom: false' "CI SBOM setting missing"
require_literal "$ci_workflow" 'scripts/ci/run-trivy-scan.sh --filesystem .' "CI filesystem Trivy scan missing"
require_literal "$ci_workflow" 'scripts/ci/run-trivy-scan.sh --image' "CI image Trivy scan missing"
require_literal "$ci_workflow" 'test ! -S /var/run/docker.sock' "CI runtime socket check missing"
require_literal "$ci_workflow" '! command -v dockerd' "CI runtime dockerd check missing"
require_literal "$ci_workflow" '! command -v containerd' "CI runtime containerd check missing"
require_literal "$ci_workflow" 'Runtime LinuxServer entrypoint and restart test' "CI normal entrypoint runtime test missing"
require_literal "$ci_workflow" "docker restart \"\$container_name\"" "CI restart persistence test missing"
require_literal "$ci_workflow" 'continue-on-error: true' "CI independent scan continuation missing"
require_literal "$ci_workflow" 'if: always()' "CI always-run scan gate missing"
require_literal "$ci_workflow" 'Gate all Trivy scans' "CI Trivy gate missing"
require_literal "$ci_workflow" 'architecture amd64' "CI amd64 sanitized report missing"
require_literal "$ci_workflow" 'architecture arm64' "CI arm64 sanitized report missing"
require_literal "$ci_workflow" 'trivy-sanitized-reports' "CI sanitized report artifact missing"
forbid_regex "$ci_workflow" '^[[:space:]]+(packages|attestations|id-token|contents):[[:space:]]*write|docker/login-action|secrets\.' "CI has write permission, registry login, or secret access"

ci_trigger_block="$(awk '
  /^on:$/ { capture = 1; next }
  capture && /^permissions:$/ { exit }
  capture { print }
' "$ci_workflow")"
expected_ci_triggers=$'  pull_request:\n    branches:\n      - main\n  push:\n    branches:\n      - main\n  workflow_dispatch:'
if [[ "$ci_trigger_block" != "$expected_ci_triggers" ]]; then
  fail "CI triggers are not exactly pull_request/main, push/main, and workflow_dispatch"
fi

ci_permission_block="$(awk '
  /^permissions:$/ { capture = 1; next }
  capture && /^concurrency:$/ { exit }
  capture && NF { print }
' "$ci_workflow")"
if [[ "$ci_permission_block" != '  contents: read' ]]; then
  fail "CI permissions are not exactly contents: read"
fi

ci_jobs="$(awk '
  /^jobs:$/ { capture = 1; next }
  capture && /^  [A-Za-z0-9_-]+:$/ {
    line = $0
    sub(/^  /, "", line)
    sub(/:$/, "", line)
    print line
  }
' "$ci_workflow")"
if [[ "$ci_jobs" != 'validate-and-build' ]]; then
  fail "CI must contain exactly the validate-and-build job"
fi

require_literal "$publish_workflow" '  push:' "publish push trigger missing"
require_literal "$publish_workflow" '    tags:' "publish tag filter missing"
require_literal "$publish_workflow" '      - "v*.*.*"' "publish tag pattern missing"
forbid_regex "$publish_workflow" '^[[:space:]]+(pull_request|workflow_dispatch|release|schedule):|^[[:space:]]+branches:' "publish has a forbidden trigger"
require_literal "$publish_workflow" '    permissions:' "publish job permissions missing"
require_literal "$publish_workflow" '    runs-on: ubuntu-24.04' "publish runner is not pinned to ubuntu-24.04"
require_literal "$publish_workflow" '      contents: read' "publish contents permission missing"
require_literal "$publish_workflow" '      packages: write' "publish packages permission missing"
require_literal "$publish_workflow" '      attestations: write' "publish attestations permission missing"
require_literal "$publish_workflow" '      "id-token": write' "publish id-token permission missing"

publish_trigger_block="$(awk '
  /^on:$/ { capture = 1; next }
  capture && /^env:$/ { exit }
  capture { print }
' "$publish_workflow")"
expected_publish_triggers=$'  push:\n    tags:\n      - "v*.*.*"'
if [[ "$publish_trigger_block" != "$expected_publish_triggers" ]]; then
  fail "publish trigger is not exactly push.tags v*.*.*"
fi

publish_jobs="$(awk '
  /^jobs:$/ { capture = 1; next }
  capture && /^  [A-Za-z0-9_-]+:$/ {
    line = $0
    sub(/^  /, "", line)
    sub(/:$/, "", line)
    print line
  }
' "$publish_workflow")"
if [[ "$publish_jobs" != 'publish' ]]; then
  fail "publish workflow must contain exactly the publish job"
fi

permission_block="$(awk '
  /^    permissions:$/ { capture = 1; next }
  capture && /^    steps:$/ { exit }
  capture && NF { sub(/^[[:space:]]+/, ""); print }
' "$publish_workflow")"
expected_permissions=$'contents: read\npackages: write\nattestations: write\n"id-token": write'
if [[ "$permission_block" != "$expected_permissions" ]]; then
  fail "publish permissions are not exactly the four approved entries"
fi

require_literal "$publish_workflow" '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' "strict release SemVer check missing"

metadata_flavor_declarations="$(awk '
  /docker\/metadata-action@/ { in_metadata = 1; next }
  in_metadata && /^[[:space:]]+- name:/ { exit }
  in_metadata && /^[[:space:]]+flavor:/ { count++ }
  END { print count + 0 }
' "$publish_workflow")"
metadata_flavor_blocks="$(awk '
  /docker\/metadata-action@/ { in_metadata = 1; next }
  in_metadata && /^[[:space:]]+- name:/ { exit }
  in_metadata && /^[[:space:]]+flavor:[[:space:]]*\|[[:space:]]*$/ { count++ }
  END { print count + 0 }
' "$publish_workflow")"
if [[ "$metadata_flavor_declarations" != "1" || "$metadata_flavor_blocks" != "1" ]]; then
  fail "publish metadata must contain exactly one active flavor block"
fi

metadata_flavor="$(awk '
  /docker\/metadata-action@/ { in_metadata = 1; next }
  in_metadata && /^[[:space:]]+- name:/ { exit }
  in_metadata && /^[[:space:]]+flavor:[[:space:]]*\|[[:space:]]*$/ {
    in_flavor = 1
    next
  }
  in_flavor && /^[[:space:]]+[A-Za-z0-9_-]+:/ {
    in_flavor = 0
    next
  }
  in_flavor {
    sub(/^[[:space:]]+/, "")
    if (NF && $0 !~ /^#/) print
  }
' "$publish_workflow")"
metadata_flavor_count="$(printf '%s\n' "$metadata_flavor" | awk '
  NF { count++ }
  END { print count + 0 }
')"
if [[ "$metadata_flavor_count" != "1" ]]; then
  fail "publish metadata flavor must contain exactly one effective line"
fi
if [[ "$metadata_flavor" != 'latest=false' ]]; then
  fail "publish metadata flavor must be exactly latest=false"
fi
if [[ "$metadata_flavor" == *"${dollar}{{"* ]]; then
  fail "publish metadata flavor must not contain a GitHub expression"
fi
if printf '%s\n' "$metadata_flavor" | grep -Eiq '^latest=(auto|true)$'; then
  fail "publish metadata flavor must not enable automatic latest tags"
fi

require_literal "$publish_workflow" '            type=semver,pattern={{version}}' "full SemVer image tag missing"
require_literal "$publish_workflow" '            type=sha,format=long' "long SHA image tag missing"

metadata_tags="$(awk '
  /docker\/metadata-action@/ { in_metadata = 1; next }
  in_metadata && /^[[:space:]]+tags:[[:space:]]*\|[[:space:]]*$/ {
    in_tags = 1
    next
  }
  in_tags && /^[[:space:]]+[A-Za-z0-9_-]+:/ { exit }
  in_tags {
    sub(/^[[:space:]]+/, "")
    if (NF && $0 !~ /^#/) print
  }
' "$publish_workflow")"
expected_metadata_tags=$'type=semver,pattern={{version}}\ntype=sha,format=long'
metadata_tag_count="$(printf '%s\n' "$metadata_tags" | awk 'NF { count++ } END { print count + 0 }')"
if [[ "$metadata_tag_count" != "2" ]]; then
  fail "publish metadata must contain exactly two active tag definitions"
fi
if [[ "$metadata_tags" != "$expected_metadata_tags" ]]; then
  fail "publish metadata tags must be exactly patch SemVer and full SHA"
fi
if printf '%s\n' "$metadata_tags" | grep -Eiq 'latest'; then
  fail "publish metadata tags must not produce latest"
fi
require_literal "$publish_workflow" '          platforms: linux/amd64' "publish build platform missing"
require_literal "$publish_workflow" '          push: true' "publish build must push"
require_literal "$publish_workflow" '          sbom: true' "publish SBOM must be enabled"
require_literal "$publish_workflow" '          provenance: false' "publish build provenance setting missing"
require_literal "$publish_workflow" "          subject-name: ghcr.io/${dollar}{{ github.repository }}" "untagged attestation subject missing"
require_literal "$publish_workflow" "          subject-digest: ${dollar}{{ steps.build.outputs.digest }}" "attestation does not use build digest"
require_literal "$publish_workflow" '          push-to-registry: true' "attestation registry push missing"
require_literal "$publish_workflow" "          password: ${dollar}{{ secrets.GITHUB_TOKEN }}" "GHCR login must use GITHUB_TOKEN"
forbid_regex "$publish_workflow" 'secrets\.(PAT|GHCR|CR_PAT)|subject-name:.*:|type=(raw|edge|ref)|pattern=\{\{major\}\}(\.\{\{minor\}\})?|prefix=v|pattern=v\{\{version\}\}' "publish includes forbidden credentials, mutable tags, a leading-v image tag, or a tagged attestation subject"

workflow_refs="$(grep -oE 'secrets\.[A-Za-z0-9_]+' "$publish_workflow" | sort -u)"
if [[ "$workflow_refs" != "secrets.GITHUB_TOKEN" ]]; then
  fail "publish uses a secret other than GITHUB_TOKEN"
fi

github_reference_count="$(grep -Fc 'secrets.GITHUB_TOKEN' "$publish_workflow")"
if [[ "$github_reference_count" != "1" ]]; then
  fail "GITHUB_TOKEN must appear exactly once in the publish login"
fi

if (( failures > 0 )); then
  printf 'Action contract validation failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Action contract validation passed: 2 workflows, %d fully pinned uses references.\n' "$uses_count"
