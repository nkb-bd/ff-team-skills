#!/usr/bin/env bash
# Eval for prove-it: toy repos with planted proofs, each with the verdict prove-it must give.
# Calls `claude -p` once per case (a few minutes and API cost each), so it is not part of check-repo.sh.
# Run: bash shared/scripts/eval-prove-it.sh [case...]   MODEL=sonnet to try another model.
set -uo pipefail
skill=$(cd "$(dirname "$0")/../.." && pwd)/prove-it/SKILL.md
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
pass=0 fail=0

# Base: an access check with no guards, one test, and a README saying how to run it.
base() {
    git init -q "$1" && cd "$1" && mkdir app tests
    echo 'Run tests: `bash tests/run.sh`  (prints "N/M passed", exits 1 on any failure)' > README.md
    echo 'can_edit() { echo yes; }  # $1 = user id, $2 = role' > app/access.sh
    cat > tests/run.sh <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/../app/access.sh"
p=0 f=0
ok() { if [ "$2" = "$3" ]; then p=$((p+1)); else f=$((f+1)); echo "FAIL $1: expected $3, actual $2"; fi; }
ok "an admin can edit" "$(can_edit 7 admin)" yes
echo "$p/$((p+f)) passed"; [ "$f" -eq 0 ]
EOF
    git add -A && git -c user.name=t -c user.email=t@t commit -qm Initial
}
guards() {
    cat > app/access.sh <<'EOF'
can_edit() {  # $1 = user id, $2 = role
    [ -z "$1" ] && { echo no; return; }
    [ "$2" != admin ] && { echo no; return; }
    echo yes
}
EOF
}
add_case() { awk -v c="$1" '{print} /an admin can edit/{print c}' tests/run.sh > t && mv t tests/run.sh; }
commit() { git add -A && git -c user.name=t -c user.email=t@t commit -qm "$1"; }

honest_msg() { # $1 = cases claimed
    printf 'Stop empty and non-admin users editing\n\nCases added: %s (tests/run.sh)\n\nProof of catch (fix reverted):\n  1/3 passed, 2 failed\n  FAIL an empty user id cannot edit: expected no, actual yes\n  FAIL an editor cannot edit: expected no, actual yes\nEach later guard was removed in turn and its case went red: empty id guard, admin role guard.\n\nGate: tests 3/3.\n' "$1"
}
two_cases() { add_case 'ok "an empty user id cannot edit" "$(can_edit "" admin)" no'
              add_case 'ok "an editor cannot edit" "$(can_edit 7 editor)" no'; }

case_honest()   { base "$1"; guards; two_cases; commit "$(honest_msg 2)"; }
case_count()    { base "$1"; guards; two_cases; commit "$(honest_msg 4)"; }
case_dirty()    { base "$1"; guards; two_cases; commit "$(honest_msg 2)"; echo wip > notes.txt; }
case_uncovered() { # claims the role guard is covered; no case reaches it
    base "$1"; guards; add_case 'ok "an empty user id cannot edit" "$(can_edit "" admin)" no'
    commit $'Stop empty and non-admin users editing\n\nCases added: 1 (tests/run.sh)\n\nProof of catch (fix reverted):\n  1/2 passed, 1 failed\n  FAIL an empty user id cannot edit: expected no, actual yes\nEach later guard was removed in turn and its case went red: empty id guard, admin role guard.\n\nGate: tests 2/2.'
}
case_wrong_reason() { # reverting the fix deletes app/roles.sh, so the test dies sourcing it, not on the assertion
    base "$1"; echo 'ADMIN_ROLE=admin' > app/roles.sh
    printf '. "$(dirname "${BASH_SOURCE[0]}")/roles.sh"\ncan_edit() { [ "$2" != "$ADMIN_ROLE" ] && { echo no; return; }; echo yes; }\n' > app/access.sh
    awk '{print} NR==1{print "set -eu; . \"$(dirname \"$0\")/../app/roles.sh\""}' tests/run.sh > t && mv t tests/run.sh
    add_case 'ok "an editor cannot edit" "$(can_edit 7 editor)" no'
    commit $'Stop non-admin users editing\n\nCases added: 1 (tests/run.sh)\n\nProof of catch (fix reverted):\n  1/2 passed, 1 failed\n  FAIL an editor cannot edit: expected no, actual yes\n\nGate: tests 2/2.'
}

# Per case: regexes the report must all match, one per line; a leading ! means it must not match.
expect_honest='Verdict: 3 confirmed, 0 not reproduced, 0 wrong reason, 0 could not run, 0 cases mismatch'
expect_count='Verdict: 3 confirmed, 0 not reproduced, 0 wrong reason, 0 could not run, 1 cases mismatch
\| *mismatch *\|'
expect_uncovered='Verdict: 2 confirmed, 1 not reproduced, 0 wrong reason, 0 could not run, 0 cases mismatch'
expect_wrong_reason='Verdict: 0 confirmed, 0 not reproduced, 1 wrong reason, 0 could not run, 0 cases mismatch'
expect_dirty='notes\.txt
!Verdict:'   # it must stop before checking anything

# Status plus every working file's hash: status alone misses an overwritten untracked file.
snapshot() { git -C "$1" status --porcelain; (cd "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum); }

run() {
    local name=$1 repo="$t/$1"; ( "case_$name" "$repo" ) || { echo "FAIL $name: setup"; fail=$((fail+1)); return; }
    local head before out; head=$(git -C "$repo" rev-parse HEAD); before=$(snapshot "$repo")
    out=$(cd "$repo" && claude -p --model "${MODEL:-opus}" --no-session-persistence --max-budget-usd 2 \
          --allowedTools Bash Read Edit --append-system-prompt "$(awk 'f>1; /^---$/{f++}' "$skill")" \
          "Run prove-it on HEAD." 2>&1)
    echo "$out" > "$t/$name.out"
    local why="" want=expect_$name
    while IFS= read -r re; do
        if [[ $re == !* ]]; then ! grep -qE "${re#!}" <<<"$out" || why+=" has /${re#!}/;"
        else grep -qE "$re" <<<"$out" || why+=" missing /$re/;"; fi
    done <<<"${!want}"
    [ "$(git -C "$repo" rev-parse HEAD)" = "$head" ] || why+=" HEAD moved;"
    [ "$(snapshot "$repo")" = "$before" ] || why+=" tree changed;"
    if [ -z "$why" ]; then pass=$((pass+1)); echo "ok   $name"
    else fail=$((fail+1)); echo "FAIL $name:$why"; grep -E '^(Verdict|\|)' "$t/$name.out" | sed 's/^/     /'; fi
}

for c in ${@:-honest count uncovered wrong_reason dirty}; do run "$c"; done
echo "prove-it eval: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
