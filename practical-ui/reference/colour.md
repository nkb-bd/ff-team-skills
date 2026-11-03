# Colour

## Contrast (WCAG 2.1 AA)
- **4.5:1** — text 18px and below (incl. button text, links, placeholder if used as the only hint, secondary text).
- **3:1** — large text (>18px bold or ≥24px regular) and non-decorative UI elements (input borders, checkbox/radio outlines, button shapes, icons that convey meaning, close icons). Purely decorative styles are exempt.
- Common failures: grey close icons, light secondary text, faint search-field borders, light placeholder text, white text on a mid-tone button, pale link colour.

### APCA (WCAG 3 draft) — perceptual, polarity-aware
Scores (higher = more contrast; thinner/smaller text needs more):
- 90 preferred body text (≥14px regular) · 75 min body (≥18px regular) · 60 other text (≥24px regular / ≥16px bold) · 45 large text (≥36px regular / ≥24px bold) and UI elements · 30 absolute min (placeholder, disabled text) · 15 non-text elements.
- Fixes WCAG 2 oddities: white-on-orange reads better than black but fails WCAG 2; dark-mode text that "passes" WCAG 2 can still be hard to read. Text-on-bg vs bg-on-text scores differ.
- **Policy**: personal projects → APCA; compliance-bound commercial work → WCAG 2 (try to pass both).

## Don't rely on colour alone
Errors: red + icon + thicker border + tinted background. Links: colour + underline. Status: colour + icon/text.

## System colours
Red = error/urgent, amber = warning/risky, green = success. Text in system colours needs 4.5:1; icons/components 3:1. Always pair with an icon.

## Hierarchy via colour
More important → more saturated, more prominent hue (red/warm stands out), higher contrast (headings darker than body).

## Light vs dark
Light UIs are the safe default. Dark UIs feel dramatic/luxurious but need extra contrast care (sunlight). Mixing light and dark areas helps grouping and hierarchy.

## Palette strategy
- Design in **black and white first** (greys included) — solve spacing, size, layout, contrast before colour. Avoid pure black on white (eye strain); use dark grey (e.g. #262626).
- Optionally tint the neutrals with the brand hue.
- **One brand colour**, applied to **interactive elements** (links, buttons) so colour teaches "clickable". Never colour non-interactive headings.
- Multiple brand colours → highest-contrast one for interaction, others only decorative (backgrounds, borders, illustrations). Never two action colours.
- Colour psychology is not universal (culture, personal history, colour blindness, context) — use loosely, test with users, pick something distinctive, avoid red as a brand action colour.
- Use opacity for hover states instead of extra palette entries.

## Use HSB
Hue 0–360, Saturation 0–100 (0 = grey), Brightness 0–100 (0 = black). Make variations by moving S and B from the brand hue.

## Light monochromatic palette (example hue 230)
| Token | Example HSB | Use | Rule |
|---|---|---|---|
| primary | 230, 70, 80 | actions (links, buttons) | ≥4.5:1 vs lightest |
| darkest | 230, 60, 20 | headings, body, labels | ≥4.5:1 vs lightest; heavily saturated very dark |
| dark | 230, 30, 45 | secondary text | ≥4.5:1 vs lightest |
| medium | 230, 20, 66 | non-decorative borders (inputs) | ≥3:1 vs lightest |
| light | 230, 10, 95 | decorative borders/dividers | none |
| lightest | 230, 2, 98 | alternate backgrounds | everything on it must still pass |
| white | 0, 0, 100 | main background | — |

Neutral option: same roles with saturation 0 for the greys, keep the primary.

Edge cases:
- **Brand colour carries meaning** (red/green/amber) → use the *darkest* variation (or a blue) for actions to avoid conflicting meanings.
- **Light brand colour** (yellow) → darken it slightly if possible; otherwise use darkest for button text and links, add a ≥3:1 border to buttons, or switch to a dark UI.

## Dark monochromatic palette (example hue 166)
| Token | Example HSB | Use | Rule |
|---|---|---|---|
| primary | 166, 50, 90 | actions | ≥4.5:1 vs dark |
| white | 0, 0, 100 | headings | ≥4.5:1 vs dark |
| lightest | 166, 4, 80 | secondary text | ≥4.5:1 vs dark |
| light | 166, 6, 65 | non-decorative borders | ≥3:1 vs dark |
| medium | 166, 8, 33 | decorative borders | none |
| dark | 166, 10, 23 | alternate backgrounds | contents must pass |
| darkest | 166, 12, 15 | main background | — |

**Dark brand colour** → lighten slightly if possible; otherwise white for button text and links plus a light-variation border on buttons.

**Always test** the palette on a real screen using every variation.

## Photo temperature
Match decorative photo colour temperature to the palette (cool palette → cooler photos). Not for product photos where true colour matters.
