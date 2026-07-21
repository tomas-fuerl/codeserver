#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

usage() {
  cat <<'EOF'
Usage: publication-audit.sh (--current-tree | --all-history)

Runs a local, non-mutating publication audit. Findings contain only categories,
locations, line numbers, object/commit IDs, and strongly redacted descriptions.
Results are written below .publication-audit/ in the audited repository.
EOF
}

die() {
  printf 'publication-audit: %s\n' "$1" >&2
  exit 2
}

mode=''
while (($# > 0)); do
  case "$1" in
    --current-tree)
      [[ -z "$mode" ]] || die 'select exactly one audit mode'
      mode='current-tree'
      ;;
    --all-history)
      [[ -z "$mode" ]] || die 'select exactly one audit mode'
      mode='all-history'
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
  shift
done

[[ -n "$mode" ]] || {
  usage >&2
  die 'an audit mode is required'
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repository_root=$(CDPATH='' cd -- "$script_dir/../.." && pwd -P)
output_dir="$repository_root/.publication-audit"
mkdir -p -- "$output_dir"

findings_file="$output_dir/${mode}-findings.tsv"
summary_file="$output_dir/${mode}-summary.txt"
inventory_file="$output_dir/${mode}-inventory.nul"
refs_file="$output_dir/${mode}-refs.txt"

printf 'severity\tcategory\tcontext\tpath\tline\tredacted_detail\n' >"$findings_file"
: >"$refs_file"

declare -A seen_findings=()
blocker_count=0
high_count=0
medium_count=0
low_count=0
informational_count=0
incomplete_count=0

# Literal dollar signs are part of the password-hash regex.
# shellcheck disable=SC2016
password_hash_regex='(\$2[abxy]\$[0-9]{2}\$[./a-z0-9]{20,}|\$argon2(id|i|d)\$|\$scrypt\$|\$6\$[./a-z0-9]{8,}\$)'

safe_field() {
  local value=$1
  value=${value//$'\t'/\\t}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  printf '%s' "$value"
}

record_finding() {
  local severity=$1
  local category=$2
  local context=$3
  local path=$4
  local line=${5:--}
  local detail=${6:-value withheld}
  local key

  key="$severity|$category|$context|$path|$line"
  [[ -z ${seen_findings[$key]+present} ]] || return 0
  seen_findings[$key]=1

  case "$severity" in
    BLOCKER) ((blocker_count += 1)) ;;
    HIGH) ((high_count += 1)) ;;
    MEDIUM) ((medium_count += 1)) ;;
    LOW) ((low_count += 1)) ;;
    INFORMATIONAL) ((informational_count += 1)) ;;
    *) die "internal error: unsupported severity $severity" ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(safe_field "$severity")" \
    "$(safe_field "$category")" \
    "$(safe_field "$context")" \
    "$(safe_field "$path")" \
    "$(safe_field "$line")" \
    "$(safe_field "$detail")" >>"$findings_file"
}

record_incomplete() {
  local context=$1
  local detail=$2
  ((incomplete_count += 1))
  record_finding 'INFORMATIONAL' 'audit.incomplete' "$context" '<audit>' '-' "$detail"
}

classify_path() {
  local context=$1
  local path=$2
  local lower_path=${path,,}
  local base=${lower_path##*/}

  case "$base" in
    .env.example|env.example|.env.sample|env.sample)
      record_finding 'LOW' 'example-configuration' "$context" "$path" '-' 'example values require placeholder review'
      return
      ;;
    stack.env|*stack.env|.env|.env.*)
      record_finding 'BLOCKER' 'sensitive-filename.environment' "$context" "$path" '-' 'environment file; contents withheld'
      return
      ;;
    id_rsa|id_ed25519|authorized_keys|known_hosts)
      record_finding 'BLOCKER' 'sensitive-filename.authentication' "$context" "$path" '-' 'authentication artifact; contents withheld'
      return
      ;;
  esac

  case "$base" in
    *.pem|*.key|*.p12|*.pfx|*.kdbx)
      record_finding 'BLOCKER' 'sensitive-filename.key-material' "$context" "$path" '-' 'key or credential container; contents withheld'
      ;;
    *.bak|*.backup|*.tar|*.tar.gz|*.tgz|*.zip|*.7z|*.log|*.dump|*.sql|*.sqlite|*.db)
      record_finding 'HIGH' 'sensitive-filename.artifact' "$context" "$path" '-' 'backup, log, archive, dump, or database artifact'
      ;;
    *.crt|*.cer)
      record_finding 'HIGH' 'sensitive-filename.certificate' "$context" "$path" '-' 'certificate metadata may expose infrastructure'
      ;;
    *secret*|*password*|*passwd*|*token*|*credential*|*auth.json)
      record_finding 'HIGH' 'sensitive-filename.credential' "$context" "$path" '-' 'credential-related filename; contents withheld'
      ;;
  esac
}

scan_regex_lines() {
  local severity=$1
  local category=$2
  local context=$3
  local path=$4
  local file=$5
  local regex=$6
  local detail=$7
  local line_number

  while IFS= read -r line_number; do
    [[ "$line_number" =~ ^[0-9]+$ ]] || continue
    record_finding "$severity" "$category" "$context" "$path" "$line_number" "$detail"
  done < <(
    LC_ALL=C grep -aEin -- "$regex" "$file" 2>/dev/null \
      | cut -d: -f1 || true
  )
}

scan_generic_assignments() {
  local context=$1
  local path=$2
  local file=$3
  local line_number

  while IFS= read -r line_number; do
    [[ "$line_number" =~ ^[0-9]+$ ]] || continue
    record_finding 'HIGH' 'secret-pattern.generic-assignment' "$context" "$path" "$line_number" 'non-placeholder credential-like assignment; value withheld'
  done < <(
    LC_ALL=C awk '
      {
        lowered = tolower($0)
        assignment = lowered ~ /^[[:space:]-]*(export[[:space:]]+)?[[:alnum:]_.-]*(password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|client[_-]?secret|auth)[[:alnum:]_.-]*[[:space:]]*[:=][[:space:]]*[^[:space:]#]{4,}/
        placeholder = lowered ~ /(change[_-]?me|replace[_-]?me|placeholder|redacted|example([._-]|$)|dummy|your[_-]|<[^>]+>|\$\{[^}]+\})/
        if (assignment && !placeholder) {
          print NR
        }
      }
    ' "$file" 2>/dev/null || true
  )
}

should_skip_content_scan() {
  local path=$1
  case "$path" in
    TASK.md|TASK-RESULT.md|docs/PUBLICATION-READINESS.md|scripts/security/publication-audit.sh|scripts/security/create-public-snapshot.sh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

scan_current_file() {
  local path=$1
  local file="$repository_root/$path"

  classify_path 'current-tree' "$path"

  if [[ -L "$file" ]]; then
    record_finding 'MEDIUM' 'filesystem.symlink' 'current-tree' "$path" '-' 'symlink target withheld; review export boundary'
    return
  fi
  [[ -f "$file" ]] || return
  should_skip_content_scan "$path" && return

  scan_regex_lines 'BLOCKER' 'secret-pattern.github-token' 'current-tree' "$path" "$file" \
    '(gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,})' 'token prefix detected; value withheld'
  scan_regex_lines 'BLOCKER' 'secret-pattern.private-key' 'current-tree' "$path" "$file" \
    '-----begin ([a-z0-9 ]+ )?private key-----' 'private-key block detected; contents withheld'
  scan_regex_lines 'BLOCKER' 'secret-pattern.aws-access-key' 'current-tree' "$path" "$file" \
    '(akia|asia)[a-z0-9]{16}' 'cloud access-key pattern detected; value withheld'
  scan_regex_lines 'BLOCKER' 'secret-pattern.credential-url' 'current-tree' "$path" "$file" \
    '(https?|ssh|git)://[^[:space:]/:@]+:[^[:space:]@/]+@' 'URL-embedded credentials detected; value withheld'
  scan_regex_lines 'HIGH' 'secret-pattern.docker-auth' 'current-tree' "$path" "$file" \
    '"(auth|identitytoken)"[[:space:]]*:[[:space:]]*"[a-z0-9+/=_-]{8,}"' 'Docker authentication structure detected; value withheld'
  scan_regex_lines 'HIGH' 'secret-pattern.password-hash' 'current-tree' "$path" "$file" \
    "$password_hash_regex" 'password-hash pattern detected; value withheld'
  scan_generic_assignments 'current-tree' "$path" "$file"

  scan_regex_lines 'MEDIUM' 'infrastructure.synology-path' 'current-tree' "$path" "$file" \
    '/volume[0-9]+(/[^[:space:]"'"'"',:]*)?' 'Synology host path detected; exact value withheld'
  scan_regex_lines 'MEDIUM' 'infrastructure.private-ipv4' 'current-tree' "$path" "$file" \
    '(^|[^0-9])((10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|(192\.168\.[0-9]{1,3}\.[0-9]{1,3})|(172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}))([^0-9]|$)' 'private IPv4 address detected; final octets withheld'
  scan_regex_lines 'MEDIUM' 'infrastructure.private-ipv6' 'current-tree' "$path" "$file" \
    '(^|[^a-f0-9:])f[cd][a-f0-9:]{2,}([^a-f0-9:]|$)' 'unique-local IPv6 address detected; value withheld'
  scan_regex_lines 'MEDIUM' 'identity.email' 'current-tree' "$path" "$file" \
    '[a-z0-9.!#$%&'"'"'*+/=?^_`{|}~-]+@[a-z0-9-]+(\.[a-z0-9-]+)+' 'email address detected; local part and domain withheld'
  scan_regex_lines 'LOW' 'infrastructure.domain' 'current-tree' "$path" "$file" \
    '([a-z0-9-]+\.)+[a-z]{2,}' 'domain reference detected; exact value withheld'
  scan_regex_lines 'LOW' 'infrastructure.url' 'current-tree' "$path" "$file" \
    '(https?|ssh|git)://[^[:space:]"'"'"'<>]+' 'network endpoint detected; exact value withheld'
  scan_regex_lines 'LOW' 'infrastructure.uid-gid' 'current-tree' "$path" "$file" \
    '(^|[^a-z0-9_])(puid|pgid|uid|gid)[[:space:]}_-]*[:=][[:space:]]*[0-9]+' 'numeric user/group identifier detected; value withheld'
  scan_regex_lines 'INFORMATIONAL' 'infrastructure.port' 'current-tree' "$path" "$file" \
    '(^|[^0-9])([0-9]{2,5}):([0-9]{2,5})([^0-9]|$)' 'published-port mapping detected; values withheld'
}

redact_email() {
  local email=$1
  local local_part domain first_local first_domain tld

  if [[ "$email" != *@* ]]; then
    printf '<invalid-address-redacted>'
    return
  fi
  local_part=${email%@*}
  domain=${email#*@}
  first_local=${local_part:0:1}
  first_domain=${domain:0:1}
  tld=${domain##*.}
  [[ "$tld" != "$domain" && ${#tld} -le 12 ]] || tld='redacted'
  printf '%s***@%s***.%s' "$first_local" "$first_domain" "$tld"
}

scan_commit_messages_and_metadata() {
  local hash author_name author_email committer_name committer_email _commit_date subject
  local identity_key redacted classification
  declare -A identities=()

  while IFS=$'\t' read -r hash author_name author_email committer_name committer_email _commit_date subject; do
    [[ "$hash" =~ ^[0-9a-f]{40,64}$ ]] || continue

    for identity_key in "$author_name|$author_email" "$committer_name|$committer_email"; do
      [[ -n ${identities[$identity_key]+present} ]] && continue
      identities[$identity_key]=1
      author_email=${identity_key#*|}
      redacted=$(redact_email "$author_email")
      classification='direct or private commit identity; assess before publication'
      if [[ ${author_email,,} == *'noreply.github.com' ]]; then
        classification='provider no-reply identity'
      fi
      record_finding 'MEDIUM' 'commit-metadata.identity' 'all-history' '<commit-metadata>' '-' "$redacted; $classification"
    done

    if [[ ${subject,,} =~ (gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,}) ]]; then
      record_finding 'BLOCKER' 'commit-message.github-token' "$hash" '<commit-message>' '-' 'token pattern in commit subject; value withheld'
    fi
    if [[ ${subject,,} =~ (password|passwd|token|secret|api[_-]?key)[[:space:]]*[:=] ]]; then
      record_finding 'HIGH' 'commit-message.credential-assignment' "$hash" '<commit-message>' '-' 'credential-like assignment in commit subject; value withheld'
    fi
  done < <(
    git -C "$repository_root" log --all \
      --format='%H%x09%an%x09%ae%x09%cn%x09%ce%x09%ad%x09%s'
  )
}

message_object_matches() {
  local object_kind=$1
  local object_name=$2
  local regex=$3

  case "$object_kind" in
    commit)
      git -C "$repository_root" show -s --format='%B' "$object_name" 2>/dev/null \
        | LC_ALL=C grep -Ei -- "$regex" >/dev/null
      ;;
    tag)
      git -C "$repository_root" cat-file -p "$object_name" 2>/dev/null \
        | LC_ALL=C grep -Ei -- "$regex" >/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

scan_message_pattern() {
  local severity=$1
  local category=$2
  local regex=$3
  local detail=$4
  local commit tag_name object_type

  while IFS= read -r commit; do
    [[ "$commit" =~ ^[0-9a-f]{40,64}$ ]] || continue
    if message_object_matches 'commit' "$commit" "$regex"; then
      record_finding "$severity" "$category" "$commit" '<commit-message>' '-' "$detail"
    fi
  done < <(git -C "$repository_root" rev-list --all)

  while IFS=$'\t' read -r tag_name object_type; do
    [[ "$object_type" == 'tag' ]] || continue
    if message_object_matches 'tag' "$tag_name" "$regex"; then
      record_finding "$severity" "$category" "tag:$tag_name" '<tag-message>' '-' "$detail"
    fi
  done < <(
    git -C "$repository_root" for-each-ref \
      --format='%(refname:short)%09%(objecttype)' refs/tags/
  )
}

scan_commit_and_tag_messages() {
  scan_message_pattern 'BLOCKER' 'message.github-token' \
    '(gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,})' 'token pattern detected; value withheld'
  scan_message_pattern 'BLOCKER' 'message.private-key' \
    '-----begin ([a-z0-9 ]+ )?private key-----' 'private-key block detected; contents withheld'
  scan_message_pattern 'BLOCKER' 'message.aws-access-key' \
    '(akia|asia)[a-z0-9]{16}' 'cloud access-key pattern detected; value withheld'
  scan_message_pattern 'BLOCKER' 'message.credential-url' \
    '(https?|ssh|git)://[^[:space:]/:@]+:[^[:space:]@/]+@' 'URL-embedded credentials detected; value withheld'
  scan_message_pattern 'HIGH' 'message.password-hash' \
    "$password_hash_regex" 'password-hash pattern detected; value withheld'
  scan_message_pattern 'HIGH' 'message.generic-assignment' \
    '^[[:space:]-]*(export[[:space:]]+)?[[:alnum:]_.-]*(password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|client[_-]?secret|auth)[[:alnum:]_.-]*[[:space:]]*[:=][[:space:]]*[^[:space:]#]{4,}' 'credential-like assignment detected; value withheld'
  scan_message_pattern 'MEDIUM' 'message.synology-path' \
    '/volume[0-9]+(/[^[:space:]"'"'"',:]*)?' 'Synology host path detected; exact value withheld'
  scan_message_pattern 'MEDIUM' 'message.private-ipv4' \
    '(^|[^0-9])((10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|(192\.168\.[0-9]{1,3}\.[0-9]{1,3})|(172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}))([^0-9]|$)' 'private IPv4 address detected; final octets withheld'
  scan_message_pattern 'MEDIUM' 'message.private-ipv6' \
    '(^|[^a-f0-9:])f[cd][a-f0-9:]{2,}([^a-f0-9:]|$)' 'unique-local IPv6 address detected; value withheld'
  scan_message_pattern 'MEDIUM' 'message.email' \
    '[a-z0-9.!#$%&'"'"'*+/=?^_`{|}~-]+@[a-z0-9-]+(\.[a-z0-9-]+)+' 'email address detected; local part and domain withheld'
  scan_message_pattern 'LOW' 'message.domain' \
    '([a-z0-9-]+\.)+[a-z]{2,}' 'domain reference detected; exact value withheld'
}

scan_history_pattern() {
  local severity=$1
  local category=$2
  local regex=$3
  local detail=$4
  local commit hit path

  while IFS= read -r commit; do
    [[ "$commit" =~ ^[0-9a-f]{40,64}$ ]] || continue
    while IFS= read -r -d '' hit; do
      path=${hit#"$commit:"}
      record_finding "$severity" "$category" "$commit" "$path" '-' "$detail"
    done < <(
      git -C "$repository_root" grep -I -l -z -E -i \
        -e "$regex" "$commit" -- 2>/dev/null || true
    )
  done < <(git -C "$repository_root" rev-list --all)
}

scan_history_paths() {
  local object_line object_id path

  while IFS= read -r object_line; do
    [[ "$object_line" == *' '* ]] || continue
    object_id=${object_line%% *}
    path=${object_line#* }
    classify_path "object:$object_id" "$path"
  done < <(git -C "$repository_root" rev-list --objects --all)
}

write_repository_state() {
  local current_branch default_remote commit_count worktree_count submodule_count lfs_count
  local ref remote_name remote_url remote_direction

  current_branch=$(git -C "$repository_root" branch --show-current)
  default_remote=$(git -C "$repository_root" config --get "branch.${current_branch}.remote" || true)
  [[ -n "$default_remote" ]] || default_remote='origin (assumed; no branch remote configured)'
  commit_count=$(git -C "$repository_root" rev-list --all --count)
  worktree_count=$(git -C "$repository_root" worktree list --porcelain | awk '$1 == "worktree" { count += 1 } END { print count + 0 }')
  submodule_count=$(git -C "$repository_root" ls-files --stage | awk '$1 == "160000" { count += 1 } END { print count + 0 }')
  lfs_count=$(
    { git -C "$repository_root" grep -I -l -e 'filter=lfs' -- .gitattributes ':(glob)**/.gitattributes' 2>/dev/null || true; } | wc -l
  )

  {
    printf 'mode=%s\n' "$mode"
    printf 'current_branch=%s\n' "$(safe_field "$current_branch")"
    printf 'default_remote=%s\n' "$(safe_field "$default_remote")"
    printf 'reachable_commits=%s\n' "$commit_count"
    printf 'worktrees=%s\n' "$worktree_count"
    printf 'submodules=%s\n' "$submodule_count"
    printf 'git_lfs_attribute_files=%s\n' "$lfs_count"
  } >>"$summary_file"

  while IFS= read -r ref; do
    printf 'local-branch\t%s\n' "$(safe_field "$ref")" >>"$refs_file"
  done < <(git -C "$repository_root" for-each-ref --format='%(refname:short)' refs/heads/)
  while IFS= read -r ref; do
    printf 'remote-branch\t%s\n' "$(safe_field "$ref")" >>"$refs_file"
  done < <(git -C "$repository_root" for-each-ref --format='%(refname:short)' refs/remotes/)
  while IFS= read -r ref; do
    printf 'tag\t%s\n' "$(safe_field "$ref")" >>"$refs_file"
  done < <(git -C "$repository_root" tag --list)

  while IFS=$'\t ' read -r remote_name remote_url remote_direction; do
    [[ -n "$remote_name" ]] || continue
    printf 'remote\t%s\tURL_REDACTED\t%s\n' \
      "$(safe_field "$remote_name")" "$(safe_field "${remote_direction:-unknown}")" >>"$refs_file"
    if [[ "$remote_url" =~ ://[^/@:[:space:]]+:[^/@[:space:]]+@ ]]; then
      record_finding 'BLOCKER' 'remote.credential-url' 'repository-config' '<remote-url>' '-' 'remote URL contains embedded credentials; value withheld'
    fi
  done < <(git -C "$repository_root" remote -v)
}

run_gitleaks_or_fallback() {
  local gitleaks_report="$output_dir/gitleaks-redacted.json"
  local gitleaks_status

  if command -v gitleaks >/dev/null 2>&1; then
    set +e
    (
      cd -- "$repository_root"
      gitleaks git --redact --no-banner --report-format json \
        --report-path "$gitleaks_report" . >/dev/null 2>&1
    )
    gitleaks_status=$?
    set -e
    case "$gitleaks_status" in
      0)
        printf 'gitleaks=available; no finding reported\n' >>"$summary_file"
        ;;
      1)
        record_finding 'BLOCKER' 'gitleaks.finding' 'all-history' '<redacted-report>' '-' 'gitleaks reported one or more findings; secret values redacted'
        printf 'gitleaks=available; redacted findings saved\n' >>"$summary_file"
        ;;
      *)
        record_incomplete 'gitleaks' "gitleaks failed with exit code $gitleaks_status; output suppressed"
        printf 'gitleaks=available; execution failed\n' >>"$summary_file"
        ;;
    esac
    return
  fi

  printf 'gitleaks=not available; redacted fallback scan executed\n' >>"$summary_file"
  scan_history_pattern 'BLOCKER' 'secret-pattern.github-token' \
    '(gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,})' 'token pattern detected; value withheld'
  scan_history_pattern 'BLOCKER' 'secret-pattern.private-key' \
    '-----begin ([a-z0-9 ]+ )?private key-----' 'private-key block detected; contents withheld'
  scan_history_pattern 'BLOCKER' 'secret-pattern.aws-access-key' \
    '(akia|asia)[a-z0-9]{16}' 'cloud access-key pattern detected; value withheld'
  scan_history_pattern 'BLOCKER' 'secret-pattern.credential-url' \
    '(https?|ssh|git)://[^[:space:]/:@]+:[^[:space:]@/]+@' 'URL-embedded credentials detected; value withheld'
  scan_history_pattern 'HIGH' 'secret-pattern.docker-auth' \
    '"(auth|identitytoken)"[[:space:]]*:[[:space:]]*"[a-z0-9+/=_-]{8,}"' 'Docker authentication structure detected; value withheld'
  scan_history_pattern 'HIGH' 'secret-pattern.password-hash' \
    "$password_hash_regex" 'password-hash pattern detected; value withheld'
  scan_history_pattern 'HIGH' 'secret-pattern.generic-assignment' \
    '^[[:space:]-]*(export[[:space:]]+)?[[:alnum:]_.-]*(password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|client[_-]?secret|auth)[[:alnum:]_.-]*[[:space:]]*[:=][[:space:]]*[^[:space:]#]{4,}' 'credential-like assignment detected; value withheld; placeholders require manual review'
}

scan_history_infrastructure() {
  scan_history_pattern 'MEDIUM' 'infrastructure.synology-path' \
    '/volume[0-9]+(/[^[:space:]"'"'"',:]*)?' 'Synology host path detected; exact value withheld'
  scan_history_pattern 'MEDIUM' 'infrastructure.private-ipv4' \
    '(^|[^0-9])((10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|(192\.168\.[0-9]{1,3}\.[0-9]{1,3})|(172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}))([^0-9]|$)' 'private IPv4 address detected; final octets withheld'
  scan_history_pattern 'MEDIUM' 'infrastructure.private-ipv6' \
    '(^|[^a-f0-9:])f[cd][a-f0-9:]{2,}([^a-f0-9:]|$)' 'unique-local IPv6 address detected; value withheld'
  scan_history_pattern 'MEDIUM' 'identity.email' \
    '[a-z0-9.!#$%&'"'"'*+/=?^_`{|}~-]+@[a-z0-9-]+(\.[a-z0-9-]+)+' 'email address detected; local part and domain withheld'
  scan_history_pattern 'LOW' 'infrastructure.domain' \
    '([a-z0-9-]+\.)+[a-z]{2,}' 'domain reference detected; exact value withheld'
}

scan_current_tree() {
  local file path find_status

  set +e
  find "$repository_root" \
    -path "$repository_root/.git" -prune -o \
    -path "$output_dir" -prune -o \
    \( -type f -o -type l \) -print0 >"$inventory_file"
  find_status=$?
  set -e
  if ((find_status != 0)); then
    record_incomplete 'current-tree' 'file inventory was incomplete; diagnostic output suppressed'
  fi

  while IFS= read -r -d '' file; do
    path=${file#"$repository_root/"}
    scan_current_file "$path"
  done <"$inventory_file"

  if git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$repository_root" check-ignore -q .publication-audit/probe; then
      record_finding 'HIGH' 'audit-output.not-ignored' 'current-tree' '.publication-audit/' '-' 'audit output directory is not ignored locally'
    fi
  fi
}

if [[ "$mode" == 'current-tree' ]]; then
  scan_current_tree
else
  git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die '--all-history requires a Git working tree'

  : >"$summary_file"
  write_repository_state
  scan_history_paths
  scan_commit_messages_and_metadata
  scan_commit_and_tag_messages
  run_gitleaks_or_fallback
  scan_history_infrastructure
fi

{
  printf 'blockers=%s\n' "$blocker_count"
  printf 'high=%s\n' "$high_count"
  printf 'medium=%s\n' "$medium_count"
  printf 'low=%s\n' "$low_count"
  printf 'informational=%s\n' "$informational_count"
  printf 'incomplete=%s\n' "$incomplete_count"
  printf 'findings_file=%s\n' ".publication-audit/${mode}-findings.tsv"
} >>"$summary_file"

printf 'Publication audit (%s): blockers=%s high=%s medium=%s low=%s informational=%s incomplete=%s\n' \
  "$mode" "$blocker_count" "$high_count" "$medium_count" "$low_count" \
  "$informational_count" "$incomplete_count"
printf 'Redacted results: .publication-audit/%s-{summary.txt,findings.tsv}\n' "$mode"

if ((incomplete_count > 0)); then
  exit 2
fi
if ((blocker_count > 0 || high_count > 0)); then
  exit 1
fi
exit 0
