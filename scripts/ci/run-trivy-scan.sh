#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

usage() {
  cat <<'EOF'
Usage:
  run-trivy-scan.sh --filesystem PATH [--architecture NAME] [--report-dir DIR]
  run-trivy-scan.sh --image IMAGE [--architecture NAME] [--report-dir DIR]
  run-trivy-scan.sh --image-archive PATH [--architecture NAME] [--report-dir DIR]

Runs a non-mutating Trivy scan for vulnerabilities, misconfigurations, and
secrets. Exit 0 means no HIGH/CRITICAL findings, 1 means blocking findings,
and 2 means a scan or input error. Optional reports contain only sanitized
vulnerability fields and aggregate secret counts.
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

[[ $# -ge 2 ]] || { usage >&2; exit 2; }
mode="$1"
target="$2"
shift 2
architecture='unknown'
report_dir=''
while (( $# > 0 )); do
  case "$1" in
    --architecture)
      [[ $# -ge 2 && -n "$2" ]] || die '--architecture requires a value'
      architecture="$2"
      shift 2
      ;;
    --report-dir)
      [[ $# -ge 2 && -n "$2" ]] || die '--report-dir requires a value'
      report_dir="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done
case "$mode" in
  --filesystem|--image|--image-archive) [[ -n "$target" ]] || die 'scan target must not be empty' ;;
  *) usage >&2; die "unknown mode: ${mode}" ;;
esac
command -v trivy >/dev/null 2>&1 || die 'trivy is required'
command -v jq >/dev/null 2>&1 || die 'jq is required'
if [[ -n "$report_dir" ]]; then
  mkdir -p -- "$report_dir" || die "cannot create report directory: $report_dir"
fi
report_file="$(mktemp)"
trap 'rm -f -- "$report_file"' EXIT
scan_args=(--format json --output "$report_file" --scanners 'vuln,misconfig,secret' --no-progress --quiet)
[[ -f .trivyignore.yaml ]] && scan_args+=(--ignorefile "$PWD/.trivyignore.yaml")
case "$mode" in
  --filesystem)
    [[ -e "$target" ]] || die "filesystem target does not exist: ${target}"
    trivy fs "${scan_args[@]}" --skip-dirs "$target/.git" "$target" || { printf '%s\n' 'Trivy filesystem scanner failed.' >&2; exit 2; } ;;
  --image)
    trivy image "${scan_args[@]}" "$target" || { printf '%s\n' 'Trivy image scanner failed.' >&2; exit 2; } ;;
  --image-archive)
    [[ -f "$target" ]] || die "image archive does not exist: ${target}"
    trivy image "${scan_args[@]}" --input "$target" || { printf '%s\n' 'Trivy image archive scanner failed.' >&2; exit 2; } ;;
esac

if [[ -n "$report_dir" ]]; then
  vuln_report="$report_dir/${architecture}-vulnerabilities.json"
  summary_report="$report_dir/${architecture}-summary.json"
  secret_report="$report_dir/${architecture}-secret-summary.json"
  jq --arg architecture "$architecture" '
    def scrub: tostring | gsub("/home/[^/]+/work/[^/]+/[^/]+";"<workspace>") | gsub("/config/workspace/[^ ]*";"<workspace>");
    [.Results[]? as $result | $result.Vulnerabilities[]? |
      {Architecture:$architecture,Target:(($result.Target // "")|scrub),Class:($result.Class // ""),Type:($result.Type // ""),VulnerabilityID:(.VulnerabilityID // ""),Severity:(.Severity // ""),PkgName:(.PkgName // ""),PkgPath:((.PkgPath // "")|scrub),InstalledVersion:(.InstalledVersion // ""),FixedVersion:(.FixedVersion // ""),Title:((.Title // "")|scrub),PrimaryURL:((.PrimaryURL // "")|scrub)}]
    | sort_by(.Architecture,.Target,.Class,.Type,.VulnerabilityID,.PkgName,.PkgPath,.InstalledVersion,.FixedVersion)
  ' "$report_file" >"$vuln_report"
  jq --arg architecture "$architecture" '
    [ .Results[]?.Vulnerabilities[]? ] as $v |
    {Architecture:$architecture,VulnerabilityCount:($v|length),FixAvailable:([$v[]|select((.FixedVersion//"") != "")]|length),NoFixAvailable:([$v[]|select((.FixedVersion//"") == "")]|length),DirectToolDependency:([$v[]|select((.PkgPath//""|test("node|pnpm|powershell|trivy|github-cli|docker";"i"))) ]|length),InheritedBaseImage:([$v[]|select(((.PkgPath//""|test("node|pnpm|powershell|trivy|github-cli|docker";"i"))|not))]|length),Critical:([$v[]|select(.Severity=="CRITICAL")]|length),High:([$v[]|select(.Severity=="HIGH")]|length),Medium:([$v[]|select(.Severity=="MEDIUM")]|length),Low:([$v[]|select(.Severity=="LOW")]|length),Unknown:([$v[]|select(.Severity=="UNKNOWN")]|length),MisconfigurationCount:([.Results[]?.Misconfigurations[]?]|length),SecretCount:([.Results[]?.Secrets[]?]|length),SecretStatus:(if ([.Results[]?.Secrets[]?]|length)>0 then "findings" else "clean" end)}
  ' "$report_file" >"$summary_report"
  jq --arg architecture "$architecture" '{Architecture:$architecture,SecretCount:([.Results[]?.Secrets[]?]|length),Status:(if ([.Results[]?.Secrets[]?]|length)>0 then "findings" else "clean" end)}' "$report_file" >"$secret_report"
fi
severity_counts="$(jq -r '[.Results[]? | (.Vulnerabilities[]?, .Misconfigurations[]?, .Secrets[]?) | .Severity] | group_by(.) | map({severity: .[0], count: length}) | .[] | [.severity, .count] | @tsv' "$report_file")"
count_severity() { local severity="$1"; printf '%s\n' "$severity_counts" | awk -v severity="$severity" '$1 == severity { print $2 + 0; found = 1 } END { if (!found) print 0 }'; }
critical_count="$(count_severity CRITICAL)"; high_count="$(count_severity HIGH)"; medium_count="$(count_severity MEDIUM)"; low_count="$(count_severity LOW)"; unknown_count="$(count_severity UNKNOWN)"
for count_name in critical_count high_count medium_count low_count unknown_count; do [[ "${!count_name}" =~ ^[0-9]+$ ]] || die 'invalid severity counts'; done
printf 'Trivy findings (%s): CRITICAL=%d HIGH=%d MEDIUM=%d LOW=%d UNKNOWN=%d\n' "$architecture" "$critical_count" "$high_count" "$medium_count" "$low_count" "$unknown_count"
if (( critical_count + high_count > 0 )); then
  printf '%s\n' 'Trivy HIGH/CRITICAL metadata (secret matches are never printed):' >&2
  jq -r '.Results[]? as $result | ($result.Vulnerabilities[]?, $result.Misconfigurations[]?) | select(.Severity == "HIGH" or .Severity == "CRITICAL") | [ .Severity, (.VulnerabilityID // .ID // .RuleID // "unknown"), (.PkgName // ""), ($result.Target // ""), (.Title // "") ] | @tsv' "$report_file" >&2
  printf '%s\n' 'Trivy scan blocked: unresolved HIGH/CRITICAL findings.' >&2
  exit 1
fi
printf '%s\n' 'Trivy scan passed: no HIGH/CRITICAL findings.'
