# Layout and spacing

## Grouping (Gestalt), strongest → subtlest
1. **Common region** — containers (border, shadow, background). Strongest; overrides spacing. Use for page structure, cards, dialogs, or when ownership is ambiguous (e.g. which author belongs to which article). Don't box everything — clutter.
2. **Proximity** — related items closer, unrelated further apart. Often replaces containers.
3. **Similarity** — same size/shape/colour = same group. Highlight one item by making it slightly different (larger, coloured border, filled button, "Most popular" badge). Things that look alike must work alike; non-interactive items must not look like buttons (e.g. badges: rounder, lighter, success colour — not the action colour).
4. **Continuity** — items on one line read as related (lists, rows). Break continuity to end a group or spotlight an item.
Combine methods; if a group already uses 2–3 of them, drop the container.

## Visual hierarchy
Levers: **size, colour, contrast, spacing, position** (top/first = important), **depth** (elevated = important).
Process for any screen:
1. Group related info into sections; order items within each section by importance.
2. Order sections by importance (most important near top).
3. Style each element by importance: title large/bold/darkest; supporting info smaller/regular/dark; replace label:value pairs with icon + text where conventional (stars for ratings); de-emphasise icons (outlined, medium colour); drop redundant labels ("Description:").
4. Make the key action prominent: primary button, sticky + elevated bar within thumb reach on mobile, price beside it (serial-position: first and last are remembered).

**Squint test**: squint/blur/zoom out — the most important elements and the screen's purpose must still be obvious.

## Depth
Higher elevation = closer = more important (and more interactive-feeling). Sticky header above content, primary button above that. Three shadows (S/M/L): small + sharp for slight lift, larger + softer for higher; light from the top; tint shadows with the darkest palette colour instead of black. Lighter surfaces on darker backgrounds look raised even without shadows.

## Box model
Margin (outside) → border → padding → content. UIs are rectangles inside rectangles.

## Units
Design @1x in points (1pt = 1px @1x, 4px @2x, 9px @3x).

## Spacing scale
8pt grid, t-shirt sizes that grow faster as they get bigger: **XS 8 · S 16 · M 24 · L 32 · XL 48 · XXL 80**. Use 4pt steps only for dense UIs.

## Spacing by relationship
Smallest spacing on the innermost rectangles, increasing outward. Example landing page: card text 8 → card padding & hero content 24 → nav links and grid gutters 32 → section padding 80. Write rules like: cards = M padding, columns = L gaps, sections = XXL vertical padding. Uniform spacing everywhere = cluttered and ambiguous.

## White space
More is usually better; when unsure, take the next spacing step up. Squint test: if elements blur together, add space.

## 12-column grid
Main layout containers snap to columns; inner elements use the spacing scale. Columns are fluid (%); 12 on desktop → 4 on mobile (3 cards × 4 cols → stacked). Gutters stay empty, fixed, narrower than columns (32 desktop → 16 mobile). Margins wider on large screens (80 desktop → 16 mobile).

## Alignment
- Left-align text; keep a straight left edge (don't let icons break it — put icons above or in line with the text column).
- Centre only short text blocks.
- Mixed-size text on one line → align to the **baseline**, not vertical centre (e.g. "$10" + "/month").
- Minimise distinct alignments per component (centred title + left body + right photo = zig-zag). Pick one; full-width button if centred on mobile.

## Proximity of actions (Fitts)
Put close/menu toggles where the open action was; put menu items at top-left near the trigger; make items large with a visible target area.

## Visibility
People don't use what they can't see. Show important nav/actions when there's room. When you must hide, make it discoverable (peek the edge of off-screen cards).

## Unbreakable UI
Design for long names, big numbers, edge cases. Prefer reflow or smaller font over clipping. If truncating, don't hide the distinguishing part — middle-truncate ("User Interface De…Chapter 2 – Typography").

## Photos
Rule of thirds: place the focal point (eyes, subject) on a grid intersection; align horizons to a third line.
