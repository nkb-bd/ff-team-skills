#!/usr/bin/env bash
# Ratchet budget lint (proof-of-catch §5): fail unless the pattern's hit count equals the budget.
# Usage: ratchet-lint.sh '<ERE pattern>' <budget> <path>...
# Proof: add the bad fixture as an extra path; the count goes over budget and it exits 1.
set -uo pipefail
[ $# -ge 3 ] || { echo "usage: ratchet-lint.sh '<pattern>' <budget> <path>..." >&2; exit 2; }
pattern=$1 budget=$2; shift 2
[[ $budget =~ ^[0-9]+$ ]] || { echo "✗ budget must be a whole number, got '$budget'" >&2; exit 2; }
hits=$(grep -rnE --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git -- "$pattern" "$@")
[ $? -le 1 ] || { echo "✗ scan failed (bad pattern or missing path); the gate did not run" >&2; exit 2; }
count=$([ -n "$hits" ] && printf '%s\n' "$hits" | wc -l | tr -d ' ' || echo 0)
if [ "$count" -gt "$budget" ]; then
    printf '%s\n' "$hits"; echo "✗ $count hits, budget $budget: new violation (above)." >&2; exit 1
elif [ "$count" -lt "$budget" ]; then
    echo "✗ $count hits, budget $budget: lower the budget to $count in this commit." >&2; exit 1
fi
echo "✓ $count/$budget"
