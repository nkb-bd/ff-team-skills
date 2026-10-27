#!/usr/bin/env bash
# Self-test for ratchet-lint.sh and hooks/commit-msg. Run: bash shared/scripts/test-gates.sh
set -u
here=$(cd "$(dirname "$0")/.." && pwd); t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
pass=0 fail=0
check() { local want=$1 name=$2; shift 2; "$@" >/dev/null 2>&1; local got=$?
    if [ "$got" -eq "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $name: exit $got, want $want"; fi; }

lint="$here/scripts/ratchet-lint.sh"; p='whereRaw\(.*fc_'
mkdir -p "$t/app" "$t/fixtures"
printf "whereRaw('fc_a')\nwhereRaw('fc_b')\n" > "$t/app/old.php"
echo "whereRaw('fc_x')" > "$t/fixtures/bad-raw.php"
check 0 "at budget"            bash "$lint" "$p" 2 "$t/app"
check 1 "fixture over budget"  bash "$lint" "$p" 2 "$t/app" "$t/fixtures/bad-raw.php"
check 1 "below budget"         bash "$lint" "$p" 3 "$t/app"
check 0 "zero hits, budget 0"  bash "$lint" "$p" 0 "$t/fixtures/none"
check 2 "missing args"         bash "$lint" "$p"

hook="$here/hooks/commit-msg"; r="$t/repo"; git init -q "$r"
msg() { printf '%s\n' "$1" > "$t/msg"; }
cd "$r" && mkdir tests && echo x > tests/a.php && echo y > app.php
git add app.php;           msg "Fix thing";                                     check 0 "no tests staged" bash "$hook" "$t/msg"
git add tests/a.php;       msg "Fix thing";                                     check 1 "tests, no proof" bash "$hook" "$t/msg"
msg $'Fix thing\n\nProof of catch (fix reverted):\n  1/2 passed';                 check 0 "tests with proof" bash "$hook" "$t/msg"
msg $'Fix thing\n\nCases added: 3';                                              check 0 "cases added"     bash "$hook" "$t/msg"
msg $'Fix thing\n\nThis has no proof of catch yet';                              check 1 "phrase mid-line" bash "$hook" "$t/msg"

echo "gates self-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
