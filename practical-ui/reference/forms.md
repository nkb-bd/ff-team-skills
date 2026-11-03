# Forms

## Layout
- **Single column.** Keeps downward momentum, removes "what's next?" decisions, and screen-magnifier users don't miss a second column.
- **Labels stacked directly above inputs** (not left — zig-zag eye path, jagged right-aligned labels, breaks on mobile).
- **Label close to its field** (~4pt), fields further apart (~16–32pt) — proximity shows ownership.
- **Stack radios and checkboxes vertically.**
- Short related fields may sit side-by-side inside the column (expiry + CVC).
- Too long? Split into steps, or **group fields under headings** ("Postal address", "Contact details").

## Fewer fields
Ask only for what's essential; explain why for sensitive data. Each field lowers completion, adds errors, and costs build time.

## Required vs optional
- Mark **both**: required with `*` (or "(required)" — safest), optional with "(optional)".
- With `*`, add "Required fields are marked with an asterisk *" at the top. Don't colour asterisks red (reads as error).
- Skip required markers only when: no optional fields exist, the form is tiny and familiar (login, single-field newsletter), one question per screen with stated reason, or testing proves it.
- Better than optional fields: **opt-in + progressive disclosure** (checkbox "Receive updates via text message" reveals a required Mobile number field).

## Field width
Match width to expected input (4-digit postcode → ~4 characters wide; CVC narrow). Equal-width fields mislead.

## Conventional styles
Rectangle input with visible border and label above. Keep iconic cues when customising (radio circle on the left of large tappable options, checkbox square, dropdown chevron). Labels inside fields make them look already filled.

## Hints
- Put critical hints **visible**, **between label and field** — not in tooltips, not below (autofill menus and on-screen keyboards cover the area below).
- Tell constraints before typing ("At least 6 characters").

## Placeholders
Don't use them as labels (they vanish, look pre-filled, fail contrast). Generally omit them. Exception: lone search field — placeholder OK if ≥4.5:1 and there's an accessible label. No instructional verbs ("Enter email here").

## Choosing controls
- ≤ ~10 options → **radio buttons** instead of a dropdown (visible, comparable, one tap). Dropdown only if space is critical.
- Long known lists (country) → **autocomplete**; ≤ ~10 suggestions; bold the *differences* between suggestions.
- Long unfamiliar lists (occupation) → split into two fields (industry → occupation).
- Small numeric changes → **stepper**: ≥48pt +/− buttons, side by side with space, "+/−" not chevrons; not for large values.
- Binary on/off defaulting off → **checkbox** if it applies on submit; **toggle** if it applies immediately. Label describes the *on* state.
- **Positive phrasing**: test by reading the checked box as "Yes, …" — "Allow automatic updates", not "Don't allow…".

## Multi-step forms
State duration and what's needed up front · chunk into a few steps of related questions (6×5 beats 30×1) · easiest questions first · show progress ("Step 2 of 3"; goal-gradient) · review-and-change screen before confirm · confirmation screen with what happens next · tertiary "Back" at top-left, primary "Next" left-aligned at the bottom.

## Contrast
Field borders and all control outlines ≥3:1. Low-contrast inputs are among the most common failures.

## Validation & errors
- **Validate on submit**, not on every keystroke. Inline/live only for: password strength rules, character limits, username availability.
- Keep the submit button **enabled**; show errors on submit.
- Error summary at the top with links that focus each invalid field.
- Per-field error message **above** the field, red + icon + stronger border/background tint.
- Error copy: what went wrong + how to fix, no blame, no "Oops", plain language ("Enter street address").
