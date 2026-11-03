# Practical UI audit checklist

Run top to bottom. For each failure record **rule → element/selector → risk → fix**. Severity: **P0** blocks or excludes users (contrast, colour-only meaning, unreachable/disabled dead ends, missing labels) · **P1** raises interaction cost or cognitive load · **P2** consistency/polish.

Prefer runtime evidence (computed styles, rendered screenshots, contrast measured on actual colours) over reading source.

## 1. Accessibility (P0)
- [ ] Text ≤18px ≥4.5:1; large text ≥3:1
- [ ] Input borders, checkbox/radio outlines, button shapes, meaningful icons ≥3:1
- [ ] Placeholder text (if it's the only hint) ≥4.5:1
- [ ] No meaning by colour alone — links underlined, errors have icon/border, statuses have icon/text
- [ ] Targets ≥48×48pt and ≥8pt apart
- [ ] Headings, links, buttons make sense out of context
- [ ] Text on photos meets contrast (overlay/gradient/blur/solid bg)
- [ ] No light-grey body text, no pure #000 on #fff

## 2. Hierarchy & simplicity (P1)
- [ ] Squint test: purpose and primary action obvious
- [ ] Exactly one primary button (or none)
- [ ] Sections ordered by importance; key action near top or sticky/elevated
- [ ] No decorative colour/lines/icons that could read as meaningful or interactive
- [ ] Non-interactive elements don't look like buttons/links (coloured headings, button-like badges)
- [ ] Important actions/nav visible or clearly discoverable; minimal hasn't removed labels
- [ ] Choices reduced, grouped, stepped, or recommended

## 3. Layout & spacing (P1/P2)
- [ ] All spacing from the scale (8/16/24/32/48/80); no odd values
- [ ] Spacing grows from inner to outer rectangles; related items closer than unrelated
- [ ] Grouping clear (container, proximity, similarity, continuity) without over-boxing
- [ ] Main layout on a 12-col grid (4 on mobile), gutters empty and consistent
- [ ] Single dominant alignment per component; straight left text edge; baseline-aligned mixed sizes
- [ ] Generous white space
- [ ] Survives long text/large numbers; truncation keeps distinguishing parts

## 4. Colour system (P1/P2)
- [ ] One action colour used for all and only interactive elements
- [ ] Palette roles respected (headings darkest, secondary dark, input borders medium, dividers light, alt bg lightest)
- [ ] System colours only for status (red/amber/green) and accessible
- [ ] Dark mode palette uses its own rules; contrast re-verified
- [ ] Shadows tinted, from the top, from 3 presets

## 5. Typography (P1/P2)
- [ ] One sans family (+ optional heading face)
- [ ] Regular + bold only
- [ ] Sizes from a type scale; body ≥18px for long text
- [ ] Body line height ≥1.5; headings tighter
- [ ] Line length 40–80 chars
- [ ] Left-aligned long text; no justify; no centred paragraphs
- [ ] Large headings slightly tightened letter spacing

## 6. Copy (P1/P2)
- [ ] Sentence case everywhere
- [ ] Concise, front-loaded, plain; no jargon/slang/unexplained abbreviations
- [ ] Descriptive headings and link text (no "Learn more" ×N, no "Click here")
- [ ] Consistent vocabulary (cart vs bag, sign up vs register…)
- [ ] Numerals with separators; no stray full stops; sibling text lengths similar
- [ ] No "my"/"your" in labels

## 7. Forms (P0/P1)
- [ ] Single column; labels above and close to fields
- [ ] No placeholder-as-label
- [ ] Required (`*`/"required") and optional ("optional") both marked; asterisk not red
- [ ] Field widths match expected input
- [ ] Hints visible, between label and field
- [ ] Radios for ≤10 options; autocomplete for long lists; steppers for small numbers; checkbox vs toggle used correctly; positive phrasing
- [ ] Long forms split into steps with progress, review, confirmation
- [ ] Validate on submit; error summary + per-field errors above fields with icon; helpful non-blaming copy

## 8. Buttons (P0/P1)
- [ ] Primary/secondary/tertiary distinguishable without colour; ≥3:1 shapes; ≥4.5:1 text
- [ ] No disabled buttons without explanation (prefer enabled + validate, remove, or lock icon)
- [ ] Left-aligned, ordered by importance; full-width stacked on mobile; Back at top-left on multi-step
- [ ] Labels are verb + noun
- [ ] Icon/text pairs balanced
- [ ] Destructive actions: low prominence, friction proportional to loss, undo where possible

## Report format
```
## Practical UI audit — <screen>
Score: P0 n · P1 n · P2 n

### P0
1. <rule> — <element> — <risk> → <fix>
...
### Quick wins (≤15 min each)
...
```
