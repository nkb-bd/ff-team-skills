#!/usr/bin/env bash
# Repo checks, run before pushing: skill frontmatter, $skill references, docs anchors, gate self-test.
# Run from the repo root: bash shared/scripts/check-repo.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
fail=0
note() { echo "✗ $*"; fail=1; }

# 1. Every active skill's frontmatter parses, and its name matches its folder.
ruby -ryaml -e '
  bad = 0
  Dir["*/SKILL.md"].reject { |p| p.start_with?("_") }.sort.each do |p|
    fm = File.read(p)[/\A---\n(.*?)\n---\n/m, 1] or (puts "✗ #{p}: no frontmatter"; bad += 1; next)
    d = YAML.safe_load(fm) rescue (puts "✗ #{p}: #{$!.message}"; bad += 1; next)
    want = File.dirname(p)
    (puts "✗ #{p}: name #{d["name"].inspect} != folder #{want}"; bad += 1) unless d["name"] == want
    (puts "✗ #{p}: no description"; bad += 1) if d["description"].to_s.strip.empty?
  end
  exit(bad.zero? ? 0 : 1)' || fail=1

# 2. Every `$skill` reference names a skill in this repo, or one installed from elsewhere.
external=" wpdb simplify verify claude-api impeccable "   # PHP var + skills not in this repo
for r in $(grep -rhoE '`\$[a-z][a-z0-9-]+`' --include=SKILL.md $(ls -d */ | grep -v '^_') | tr -d '`$' | sort -u); do
    [ -d "$r" ] || [[ $external == *" $r "* ]] || note "unknown skill reference \$$r"
done

# 3. Every docs link to guide.html#anchor, and every in-page #anchor in guide.html, exists.
for a in $({ grep -ohE 'guide\.html#[a-z0-9-]+' docs/*.html | cut -d# -f2
              grep -oE 'href="#[a-z0-9-]+"' docs/guide.html | cut -d'"' -f2 | cut -c2-; } | sort -u); do
    grep -q "id=\"$a\"" docs/guide.html || note "docs/guide.html has no id=\"$a\""
done

# 4. The gates' own self-test.
bash shared/scripts/test-gates.sh || fail=1

[ "$fail" -eq 0 ] && echo "✓ repo checks passed"; exit "$fail"
