# Buttons

## Three weights
- **Primary** — solid fill in the action colour, white (or darkest) text, rounded rectangle. The single most important action.
- **Secondary** — no fill, action-colour border + text, same shape. Alternatives or equal-weight actions. Avoid other-colour fills (clash, colour-blind confusion) and light-grey fills/outlines (look disabled).
- **Tertiary** — looks like a link: action-colour text, underlined (for colour-blind users), no box. Least important, multiple, or destructive actions.
Add sizes (small/large) only if the UI needs them.

## Common mistakes to reject
- Secondary fill/shape below 3:1 against the background (shape invisible to low-vision users).
- Light-grey secondary that reads as disabled.
- Primary and secondary differing only by colour (colour-blind can't tell) or by <3:1.
- Tertiary distinguished only by colour (no underline).
- Different shapes for buttons that behave the same.
- Primary and secondary with near-equal visual weight (hierarchy unclear).

## Rules
- Hierarchy must hold without colour.
- Button shape ≥3:1 vs background; text ≥4.5:1 vs fill.
- Identical-style buttons must differ by ≥3:1.
- Target ≥48×48pt; frequently used buttons bigger; ≥8pt between buttons (16pt safer).
- For small elements, extend the hit area beyond the visual (and hint at it, e.g. a visible row border) so people don't aim precisely.

## One primary per screen
If nothing is clearly most important, use secondaries/tertiaries. Lists of identical actions ("Follow" ×5) → secondary or tertiary, never 5 primaries. Equal-weight choices ("Report" / "Don't report") get equal prominence — don't bias.

## Avoid disabled buttons
They strand users without feedback, fail contrast, and aren't keyboard-focusable. Alternatives:
1. **Enable and validate on submit** (show what's missing).
2. **Remove unavailable actions** and explain why ("Request to follow this person to see their work and contact them" + [Request follow]).
3. **Lock icon** on a normal-contrast button (great for premium features) + explain how to unlock.
4. If you must disable: explanatory text next to it or a tooltip, and keep it keyboard-focusable so the tooltip is reachable.

## Alignment & order
- Left-align, ordered most → least important (F-pattern, magnifier users, shortest path for most people).
- Mobile: full-width, stacked top → bottom by importance (one-handed reach).
- Small dialogs: left-align for consistency (right-aligned is a macOS convention; either is fine if hierarchy is correct — be consistent).
- Multi-step forms: primary left-aligned at the bottom; tertiary "Back" at the top-left (not bottom-right where it gets hit by mistake).
- Exception: single-field forms (search, email subscribe) — button attached to the right of the field.

## Label = verb + noun
"Save post", "Delete article", "Send invite". Must make sense out of context (screen readers list buttons; many users read buttons first). Never "OK", "Yes", "Submit" alone.

## Icon + text pairs
Match stroke weight and size to the text; if the icon is heavier/larger, lower its contrast (medium palette colour) to balance.

## Destructive actions — friction proportional to loss
- **Initial**: make it less prominent (tertiary), further away, or progressively disclosed. Don't colour it red at this stage (red attracts).
- **Light** (small loss): simple confirm dialog ("Delete message?" [Delete message] [Cancel]).
- **Medium**: confirm with red destructive button and/or warning icon; state irreversibility.
- **Heavy** (large loss, e.g. account): require a confirmation checkbox ("I confirm I want to delete my account") before the button works.
- **Best**: allow **undo** ("Message deleted" [Restore message]) instead of friction.
