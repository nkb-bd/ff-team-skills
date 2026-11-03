# Fundamentals

## The three costs to minimise

**Usability risk** — any detail some users might misread or fail to use. Typical risks: thin/light-grey text, icon-only buttons, coloured non-link headings, low-contrast borders. Assume a diverse audience (low vision, low literacy, reduced dexterity, cognitive impairment); fix vague or confusing details *before* paying for usability testing.

**Interaction cost** — total physical + mental effort (looking, scrolling, reading, clicking, typing, waiting, remembering). Biggest levers:
- *Fitts's Law*: keep actions near what they act on, make targets big (≥48pt).
- *Reduce distractions*: no animated banners, needless pop-ups, decorative noise.
- *Hick's Law*: fewer, simpler choices; highlight recommended/popular ones.
- Example: quantity dropdown + far "Add to cart" (3 clicks + scroll) → stepper + adjacent left-aligned button (2 clicks).

**Cognitive load** — brain power needed. Reduce by removing unnecessary styles/info/decisions, chunking into groups, using familiar patterns, being consistent, and having a clear visual hierarchy. Break big tasks (long forms) into steps.

## Every detail needs a rationale
Design decisions must be defensible with logic ("secondary text is lower contrast to establish hierarchy"), not taste ("looks nice"). Use rationales in reviews and critiques.

## Design system in 3 steps
1. **Predefined style options**
   - Colour palette with a purpose per colour (see `colour.md`).
   - Type scale, e.g. Major Third 1.250: H1 44 / H2 36 / H3 28 / H4 22 bold, Body 18 / Small 15 regular.
   - Spacing: XS 8 · S 16 · M 24 · L 32 · XL 48 · XXL 80 (pt).
   - Shadows: small / medium / large. Radii: 8 / 16 / 32pt for small / medium / large elements.
2. **Reusable modules** — atoms (button, avatar, input) → composites (avatar+text → card → card list) → page templates. Keep a component library.
3. **Usage guidelines** — document *how* to use styles/components and how to write copy. Example rules: actions use the primary colour; sentence case; left-align buttons and text; avoid disabled buttons; front-load text; concise plain language.

## Accessibility
- Target WCAG 2.1 AA as the floor (often a legal requirement). Good accessibility = great usability; it also covers temporary/situational disability (injury, sunlight glare).
- **Screen readers**: users tab/swipe through elements and often list all headings or links → headings, links, and buttons must make sense out of context.
- **Screen magnifiers** (more common than readers): users see a small area at a time → right-aligned or far-off actions get missed; keep related things close and left-aligned.

## Use common patterns (Jakob's Law)
People expect your product to work like the others they use. Conventional accordions, form fields (rectangle with label on top), checkboxes (square + tick), underlined links. Innovate on the product's unique value, not on basic controls. On iOS/Android follow platform guidelines unless they test poorly or are inaccessible.

## 80/20 rule
~20% of features/issues/page areas drive ~80% of use/complaints/attention. Optimise the common path before edge cases.

## Keep costs in mind
Reuse existing design systems/UI kits and icon sets, stick to familiar patterns (less testing), learn how UIs are built, talk to developers early — the simple option is usually cheaper to build and easier to use.

## Consistency
Similar elements look and behave the same — within the product (via the design system) and with established products.
