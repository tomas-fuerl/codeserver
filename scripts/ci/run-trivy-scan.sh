#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

usage() {
  cat <<'EOF'
Usage:
  run-trivy-scan.sh --filesystem PATH
  run-trivy-scan.sh --image IMAGE
  run-trivy-scan.sh --image-archive PATH

Runs a non-mutating Trivy scan for vulnerabilities, misconfigurations, and
secrets. HIGH and CRITICAL findings return exit code 1; scanner or input
errors return exit code 2. Findings are counted from a private temporary JSON
report and are not printed, so secret matches cannot leak into CI logs.
EOF
}

die() {
  printf 'Trivy scan: %s\n' "$1" >&2
  exit 2
}

if [[ $# -eq 1 && ( "$1" == '-h' || "$1" == '--help' ) ]]; then
  usage
  exit 0
fi

[[ $# -eq 2 ]] || {
  usage >&2
  exit 2
}

mode="$1"
target="$2"
case "$mode" in
  --filesystem|--image|--image-archive)
    [[ -n "$target" ]] || die 'scan target must not be empty'
    ;;
  *)
    usage >&2
    die "unknown mode: ${mode}"
    ;;
esac

command -v trivy >/dev/null 2>&1 || die 'trivy is required'
command -v jq >/dev/null 2>&1 || die 'jq is required'

report_file="$(mktemp)"
trap 'rm -f -- "$report_file"' EXIT

scan_args=(
  --format json
  --output "$report_file"
  --scanners 'vuln,misconfig,secret'
  --no-progress
  --quiet
)

case "$mode" in
  --filesystem)
    [[ -e "$target" ]] || die "filesystem target does not exist: ${target}"
    trivy fs "${scan_args[@]}" --skip-dirs "$target/.git" "$target" || {
      printf '%s\n' 'Trivy filesystem scanner failed before findings could be evaluated.' >&2
      exit 2
    }
    ;;
  --image)
    trivy image "${scan_args[@]}" "$target" || {
      printf '%s\n' 'Trivy image scanner failed before findings could be evaluated.' >&2
      exit 2
    }
    ;;
  --image-archive)
    [[ -f "$target" ]] || die "image archive does not exist: ${target}"
    trivy image "${scan_args[@]}" --input "$target" || {
      printf '%s\n' 'Trivy image archive scanner failed before findings could be evaluated.' >&2
      exit 2
    }
    ;;
esac

severity_counts="$(jq -r '[.Results[]? | (.Vulnerabilities[]?, .Misconfigurations[]?, .Secrets[]?) | .Severity] | group_by(.) | map({severity: .[0], count: length}) | .[] | [.severity, .count] | @tsv' "$report_file")"
count_severity() {
  local severity="$1"
  printf '%s\n' "$severity_counts" | awk -v severity="$severity" '$1 == severity { print $2 + 0; found = 1 } END { if (!found) print 0 }'
}

critical_count="$(count_severity CRITICAL)"
high_count="$(count_severity HIGH)"
medium_count="$(count_severity MEDIUM)"
low_count="$(count_severity LOW)"
unknown_count="$(count_severity UNKNOWN)"
for count_name in critical_count high_count medium_count low_count unknown_count; do
  [[ "${!count_name}" =~ ^[0-9]+$ ]] || die 'Trivy JSON report did not contain valid severity counts'
done
printf 'Trivy findings: CRITICAL=%d HIGH=%d MEDIUM=%d LOW=%d UNKNOWN=%d\n' \
  "$critical_count" "$high_count" "$medium_count" "$low_count" "$unknown_count"
if (( critical_count + high_count > 0 )); then
  printf '%s\n' 'Trivy HIGH/CRITICAL metadata (secret matches are never printed):' >&2
  jq -r '.Results[]? as $result | ($result.Vulnerabilities[]?, $result.Misconfigurations[]?, $result.Secrets[]?) | select(.Severity == "HIGH" or .Severity == "CRITICAL") | [ .Severity, (.VulnerabilityID // .ID // .RuleID // "unknown"), (.PkgName // ""), ($result.Target // ""), (.Title // "") ] | @tsv' "$report_file" >&2
  printf '%s\n' 'Trivy scan blocked: unresolved HIGH/CRITICAL findings.' >&2
  exit 1
fi

printf '%s\n' 'Trivy scan passed: no HIGH/CRITICAL findings.'
