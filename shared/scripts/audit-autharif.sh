#!/usr/bin/env bash
# audit-autharif.sh
# Harvest autharif's review comments across configured repos and report on what
# pr-reviewer's criteria packs cover (and what they miss).
#
# Three modes:
#   - HARVEST (default): pulls autharif comments since --since, classifies each
#     headline, writes catalog files. Exits non-zero if >5% are unmapped.
#   - VALIDATE (--validate): reads the test corpus and confirms each row maps to
#     the expected detector. Exits non-zero if accuracy < 80%.
#   - DIFF (--diff-with-pr <REPO> <PR>): for one PR, shows the gap between local
#     pr-reviewer-like classification and autharif's actual GitHub findings.
#
# Conventions match matt-pocock/diagnose: tagged stderr logs, build-loop-first.

set -euo pipefail

# -----------------------------------------------------------------------------
# defaults
# -----------------------------------------------------------------------------
DEFAULT_REPOS=(
  "WPManageNinja/fluent-player-dev"
  "WPManageNinja/fluent-cart"
  "WPManageNinja/fluent-crm"
  "WPManageNinja/fluent-members"
  "fluentform/fluentform"
)

SINCE=""                         # ISO date (YYYY-MM-DD)
REPOS=("${DEFAULT_REPOS[@]}")
OUT_DIR=""                       # if empty, prints summary to stdout only
MODE="harvest"
CORPUS=""
DIFF_REPO=""
DIFF_PR=""
THRESHOLD_UNMAPPED=5             # % unmapped that fails the harvest
THRESHOLD_ACCURACY=80            # % accuracy required in validate mode

REVIEWER="autharif"

# Resolve script dir → repo root → criteria-packs dir
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
AGENT_SKILLS_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"
CRITERIA_DIR="${AGENT_SKILLS_ROOT}/pr-reviewer/references"

log() { echo "[audit-autharif:$1] ${*:2}" >&2; }

# -----------------------------------------------------------------------------
# usage
# -----------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Harvest mode (default):
  --since YYYY-MM-DD          Earliest merge date to include (default: 5 days ago)
  --repos R1,R2,...           Comma-separated repo list (default: 5 active WPMN repos)
  --out DIR                   Write catalog files to DIR (TSV + NDJSON + summary.md)

Validate mode:
  --validate                  Run validation against the test corpus
  --corpus PATH               Path to TSV corpus file (default: pr-reviewer/references/test-corpus.tsv)

Diff mode:
  --diff-with-pr REPO PR      Compare local classification vs autharif's actual findings on one PR

Common:
  --threshold-unmapped N      % unmapped that fails harvest (default: 5)
  --threshold-accuracy N      % accuracy required in validate mode (default: 80)
  -h | --help                 Show this help

Examples:
  $(basename "$0")                                          # last 5 days, 5 repos, summary to stdout
  $(basename "$0") --since 2026-04-01 --out /tmp/audit/    # explicit window, write catalog
  $(basename "$0") --validate                               # check corpus → detector mapping
  $(basename "$0") --diff-with-pr WPManageNinja/fluent-cart 1641
EOF
}

# -----------------------------------------------------------------------------
# arg parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)            SINCE="$2"; shift 2 ;;
    --repos)            IFS=',' read -ra REPOS <<< "$2"; shift 2 ;;
    --out)              OUT_DIR="$2"; shift 2 ;;
    --validate)         MODE="validate"; shift ;;
    --corpus)           CORPUS="$2"; shift 2 ;;
    --diff-with-pr)     MODE="diff"; DIFF_REPO="$2"; DIFF_PR="$3"; shift 3 ;;
    --threshold-unmapped)  THRESHOLD_UNMAPPED="$2"; shift 2 ;;
    --threshold-accuracy)  THRESHOLD_ACCURACY="$2"; shift 2 ;;
    -h | --help)        usage; exit 0 ;;
    *) log "drop" "unknown arg: $1"; usage; exit 2 ;;
  esac
done

# Default --since to 5 days ago if not set (BSD vs GNU date compatible)
if [[ -z "$SINCE" ]]; then
  if date -v-5d +%Y-%m-%d >/dev/null 2>&1; then
    SINCE="$(date -v-5d +%Y-%m-%d)"           # BSD / macOS
  else
    SINCE="$(date -d '5 days ago' +%Y-%m-%d)" # GNU
  fi
fi

# -----------------------------------------------------------------------------
# classify_headline <headline>
# Returns the detector name on stdout, or "unmapped".
# Patterns are derived from the criteria packs' "Smell patterns" and headlines.
# -----------------------------------------------------------------------------
classify_headline() {
  local h="$1"
  local hl="$(echo "$h" | tr '[:upper:]' '[:lower:]')"

  # a11y
  if [[ "$hl" == *mouse-only* || "$hl" == *keyboard-accessible* || "$hl" == *keyboard* \
     || "$hl" == *aria-* || "$hl" == *"aria "* || "$hl" == *aria_* \
     || "$hl" == *"focus indicator"* || "$hl" == *"focus visibility"* || "$hl" == *"focus removed"* \
     || "$hl" == *"screen reader"* || "$hl" == *"aria label"* || "$hl" == *"accessible name"* \
     || "$hl" == *"aria state"* || "$hl" == *"tab order"* || "$hl" == *tabindex* ]]; then
    echo "a11y"; return
  fi

  # async-state
  if [[ "$hl" == *stale*async* || "$hl" == *stale*response* || "$hl" == *"stale offset"* \
     || "$hl" == *race* || "$hl" == *concurrent* \
     || "$hl" == *cancel*orphan* || "$hl" == *cancel*race* \
     || "$hl" == *retry*concurrent* || "$hl" == *progress*double* \
     || "$hl" == *remount* || "$hl" == *"start over"* \
     || "$hl" == *"request id"* || "$hl" == *request-id* || "$hl" == *loading-race* \
     || "$hl" == *"not persisted"* || "$hl" == *"total never updates"* \
     || "$hl" == *"not loaded after"* || "$hl" == *"not loaded after enabling"* ]]; then
    echo "async-state"; return
  fi

  # rbac-alignment (also catches a few security cases per dedup precedence)
  if [[ "$hl" == *capability*conflict* || "$hl" == *capability*mismatch* \
     || "$hl" == *rbac* || "$hl" == *permission*mismatch* \
     || "$hl" == *"ui gate"* || "$hl" == *"api permission"* \
     || "$hl" == *read-only*capability* || "$hl" == *published*gate* \
     || "$hl" == *ownership* || "$hl" == *nopriv* || "$hl" == *permission_callback* \
     || "$hl" == *unvalidated*redirect* || "$hl" == *"open redirect"* \
     || "$hl" == *"hardcoded https"* || "$hl" == *"production config"* \
     || "$hl" == *"dev config"* ]]; then
    echo "rbac-alignment"; return
  fi

  # bc-regression
  if [[ "$hl" == *backward-compat* || "$hl" == *"backward compat"* \
     || "$hl" == *default*overridden* || "$hl" == *default*changed* \
     || "$hl" == *"payload key"* || "$hl" == *"key renamed"* \
     || "$hl" == *"shape mismatch"* || "$hl" == *"contract mismatch"* \
     || "$hl" == *"contract drift"* || "$hl" == *hardcoded*to*specific* \
     || "$hl" == *"column limits"* || "$hl" == *"column limit"* \
     || "$hl" == *"now excludes"* || "$hl" == *excludes*non-default* \
     || "$hl" == *missing-setting* || "$hl" == *default*disabled* \
     || "$hl" == *compat* ]]; then
    echo "bc-regression"; return
  fi

  # error-state
  if [[ "$hl" == *"blank ui"* || "$hl" == *"not found"* \
     || "$hl" == *stuck*loading* || "$hl" == *"stays locked"* \
     || "$hl" == *"hang forever"* || "$hl" == *hidden* \
     || "$hl" == *invisible* || "$hl" == *"loading state"* \
     || "$hl" == *"api failure"* || "$hl" == *"fetch error"* \
     || "$hl" == *"error state"* || "$hl" == *error-state* \
     || "$hl" == *hide*failure* || "$hl" == *upsell*disabled* \
     || "$hl" == *hard-disabled* || "$hl" == *unconditional*loader* \
     || "$hl" == *"blank messages"* || "$hl" == *renders*blank* \
     || "$hl" == *"silent sync"* || "$hl" == *silent*failure* \
     || "$hl" == *silent*sync* ]]; then
    echo "error-state"; return
  fi

  # perf-and-integrity (perf + data-integrity, combined)
  if [[ "$hl" == *"n+1"* || "$hl" == *per-row* || "$hl" == *"aggregate quer"* \
     || "$hl" == *unbounded* || "$hl" == *"page cap"* \
     || "$hl" == *"transient writes"* || "$hl" == *per-product*lookup* \
     || "$hl" == *repeated*lookup* || "$hl" == *full*analysis*remount* \
     || "$hl" == *"meta is not uniquely"* || "$hl" == *non-unique* \
     || "$hl" == *"only one subscription"* || "$hl" == *only*matching* \
     || "$hl" == *duplicate*method* || "$hl" == *"inverted date"* \
     || "$hl" == *inconsistent*activation* || "$hl" == *atomic* \
     || "$hl" == *skipped*data-integrity* || "$hl" == *"data integrity"* \
     || "$hl" == *"auto-skipped"* || "$hl" == *db*values*are*string* \
     || "$hl" == *"string values"* || "$hl" == *"string allow_"* \
     || "$hl" == *silently*wipe* || "$hl" == *silently*destroy* \
     || "$hl" == *"empty normalized"* || "$hl" == *normalizer*empty* \
     || "$hl" == *destructive*write* || "$hl" == *"wipes existing"* ]]; then
    echo "perf-and-integrity"; return
  fi

  # traceability (also catches ui-logic per dedup precedence)
  if [[ "$hl" == *stub* || "$hl" == *nonfunctional* \
     || "$hl" == *"phase 2"* || "$hl" == *unimplemented* \
     || "$hl" == *"hardcoded dummy"* || "$hl" == *"dummy data"* \
     || "$hl" == *"hardcoded menu"* || "$hl" == *"unused markup"* \
     || "$hl" == *unreachable* || "$hl" == *broken*trace* \
     || "$hl" == *setting-to-render* || "$hl" == *"render variable"* \
     || "$hl" == *broken*chain* || "$hl" == *fallback*chain* \
     || "$hl" == *"cta label"* || "$hl" == *"not match"* \
     || "$hl" == *config*bypassed* \
     || "$hl" == *"clearing input"* || "$hl" == *disabled*selectable* \
     || "$hl" == *"panel collapsed"* || "$hl" == *"filter group"* \
     || "$hl" == *chip* || "$hl" == *"search toggle"* \
     || "$hl" == *undefined*breaks* || "$hl" == *undefined*variable* \
     || "$hl" == *breaks*rendering* || "$hl" == *"breaks "*"chain"* \
     || "$hl" == *redundant*write* || "$hl" == *redundant*rest* \
     || "$hl" == *"redundant per-"* || "$hl" == *redundant*put* \
     || "$hl" == *"still run after"* || "$hl" == *"after backend hook"* ]]; then
    echo "traceability"; return
  fi

  echo "unmapped"
}

# -----------------------------------------------------------------------------
# harvest_repo <repo>
# Emits TSV: repo \t pr \t kind \t path \t line \t headline \t detector
# -----------------------------------------------------------------------------
harvest_repo() {
  local repo="$1"
  log "detector" "harvesting $repo since $SINCE"

  local prs
  prs="$(gh pr list --repo "$repo" --state merged \
                    --search "merged:>=${SINCE}" \
                    --json number --limit 100 2>/dev/null \
        | jq -r '.[].number' || true)"

  if [[ -z "$prs" ]]; then
    log "detector" "  no PRs in window for $repo"
    return 0
  fi

  for n in $prs; do
    # inline comments
    gh api "repos/$repo/pulls/$n/comments" 2>/dev/null \
      | jq -c --arg repo "$repo" --argjson pr "$n" '
          .[]
          | select(.user.login=="'"$REVIEWER"'")
          | { repo:$repo, pr:$pr, kind:"inline", path: (.path//"-"), line:(.line//"-"|tostring), body }' \
      || true
    # issue comments
    gh api "repos/$repo/issues/$n/comments" 2>/dev/null \
      | jq -c --arg repo "$repo" --argjson pr "$n" '
          .[]
          | select(.user.login=="'"$REVIEWER"'")
          | { repo:$repo, pr:$pr, kind:"issue", path:"-", line:"-", body }' \
      || true
    # reviews
    gh api "repos/$repo/pulls/$n/reviews" 2>/dev/null \
      | jq -c --arg repo "$repo" --argjson pr "$n" '
          .[]
          | select(.user.login=="'"$REVIEWER"'")
          | { repo:$repo, pr:$pr, kind:"review", path:"-", line:"-", body }' \
      || true
  done
}

# -----------------------------------------------------------------------------
# extract_headline_and_classify
# Stdin: NDJSON of {repo, pr, kind, path, line, body}
# Stdout: TSV: repo \t pr \t kind \t path \t line \t headline \t detector
# -----------------------------------------------------------------------------
extract_and_classify() {
  while IFS= read -r line; do
    local headline
    # Try <strong>...</strong>, then <h3>Summary</h3>, fallback to first 100 chars
    headline="$(echo "$line" \
      | jq -r '.body // ""' \
      | tr -d '\r' \
      | tr '\n' ' ' \
      | grep -oE '<strong>[^<]+</strong>' \
      | head -1 \
      | sed -E 's|</?strong>||g')"
    if [[ -z "$headline" ]]; then
      # try summary header
      headline="$(echo "$line" \
        | jq -r '.body // ""' \
        | tr -d '\r' \
        | tr '\n' ' ' \
        | grep -oE '<h3>[^<]+</h3>' \
        | head -1 \
        | sed -E 's|</?h3>||g')"
      [[ -n "$headline" ]] && headline="[summary] ${headline}"
    fi
    [[ -z "$headline" ]] && continue   # skip non-substantive entries

    local repo pr kind path line_n
    repo="$(echo "$line" | jq -r '.repo')"
    pr="$(echo "$line" | jq -r '.pr')"
    kind="$(echo "$line" | jq -r '.kind')"
    path="$(echo "$line" | jq -r '.path')"
    line_n="$(echo "$line" | jq -r '.line')"

    local detector
    detector="$(classify_headline "$headline")"
    printf '%s\t#%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$pr" "$kind" "$path" "$line_n" "$headline" "$detector"
  done
}

# -----------------------------------------------------------------------------
# mode dispatch
# -----------------------------------------------------------------------------
case "$MODE" in
  harvest)
    log "plan" "since=$SINCE  repos=${#REPOS[@]}  out=${OUT_DIR:-stdout}"
    [[ -n "$OUT_DIR" ]] && mkdir -p "$OUT_DIR"

    tmp_ndjson="$(mktemp)"
    for r in "${REPOS[@]}"; do harvest_repo "$r" >> "$tmp_ndjson"; done

    log "detector" "raw items: $(wc -l < "$tmp_ndjson")"

    tmp_tsv="$(mktemp)"
    extract_and_classify < "$tmp_ndjson" > "$tmp_tsv"
    total="$(wc -l < "$tmp_tsv" | awk '{print $1}')"
    unmapped="$(awk -F'\t' '$7=="unmapped"' "$tmp_tsv" | wc -l | awk '{print $1}')"

    log "detector" "classified: total=$total  unmapped=$unmapped"

    # Per-detector breakdown
    {
      echo "# autharif catalog (since $SINCE)"
      echo ""
      echo "Total: $total  |  Unmapped: $unmapped"
      echo ""
      echo "## Per-detector counts"
      echo ""
      echo "| detector | count |"
      echo "|---|---:|"
      awk -F'\t' '$7!="" { print $7 }' "$tmp_tsv" | sort | uniq -c | sort -rn \
        | awk '{ printf "| %s | %d |\n", $2, $1 }'
      echo ""
      if [[ "$unmapped" -gt 0 ]]; then
        echo "## Unmapped headlines (need new criteria pack rules)"
        echo ""
        awk -F'\t' '$7=="unmapped"' "$tmp_tsv" \
          | awk -F'\t' '{ printf "- `%s` %s `%s:%s` — %s\n", $1, $2, $4, $5, $6 }'
      fi
    } | tee "${OUT_DIR:-/dev/null}/${OUT_DIR:+summary.md}"

    if [[ -n "$OUT_DIR" ]]; then
      cp "$tmp_tsv" "$OUT_DIR/inline-headlines.tsv"
      cp "$tmp_ndjson" "$OUT_DIR/autharif-clean.ndjson"
      log "detector" "wrote $OUT_DIR/{summary.md,inline-headlines.tsv,autharif-clean.ndjson}"
    fi

    rm -f "$tmp_ndjson" "$tmp_tsv"

    if [[ "$total" -gt 0 ]]; then
      pct_unmapped=$(( unmapped * 100 / total ))
      if [[ "$pct_unmapped" -gt "$THRESHOLD_UNMAPPED" ]]; then
        log "drop" "$pct_unmapped% unmapped (threshold $THRESHOLD_UNMAPPED%) — criteria packs need updating"
        exit 1
      fi
    fi
    ;;

  validate)
    [[ -z "$CORPUS" ]] && CORPUS="${CRITERIA_DIR}/test-corpus.tsv"
    if [[ ! -f "$CORPUS" ]]; then
      log "drop" "corpus not found: $CORPUS"
      exit 2
    fi

    log "plan" "validating $(wc -l < "$CORPUS" | awk '{print $1-1}') corpus rows"
    pass=0; fail=0
    while IFS=$'\t' read -r repo pr file_line headline expected; do
      [[ "$repo" == "repo" ]] && continue
      [[ -z "$expected" ]] && continue
      actual="$(classify_headline "$headline")"
      if [[ "$actual" == "$expected" ]]; then
        pass=$((pass+1))
      else
        fail=$((fail+1))
        echo "FAIL: '$headline' → got '$actual', expected '$expected'"
      fi
    done < "$CORPUS"

    total=$((pass+fail))
    pct=$(( pass * 100 / (total > 0 ? total : 1) ))
    log "detector" "validate: $pass/$total ($pct%)"
    if [[ "$pct" -lt "$THRESHOLD_ACCURACY" ]]; then
      log "drop" "accuracy below threshold ($THRESHOLD_ACCURACY%)"
      exit 1
    fi
    ;;

  diff)
    [[ -z "$DIFF_REPO" || -z "$DIFF_PR" ]] && { usage; exit 2; }
    log "plan" "diff $DIFF_REPO #$DIFF_PR"
    {
      gh api "repos/$DIFF_REPO/pulls/$DIFF_PR/comments" 2>/dev/null \
        | jq -c --arg repo "$DIFF_REPO" --argjson pr "$DIFF_PR" '
            .[]
            | select(.user.login=="'"$REVIEWER"'")
            | { repo:$repo, pr:$pr, kind:"inline", path:(.path//"-"), line:(.line//"-"|tostring), body }'
    } | extract_and_classify \
      | awk -F'\t' '{ printf "%-25s | %s:%s | %s\n", $7, $4, $5, $6 }' \
      | sort
    ;;
esac
