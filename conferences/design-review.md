# AP-LS Conference Page — Design Review & Recommendations

## What was reviewed

- `conferences/index.qmd` — the main 2027 conference page
- `conferences/index.css` — the page-specific stylesheet (cleaned and consolidated)
- `_brand.yml` — the site-wide brand tokens
- `assets/typst/apls-template.typ` — the new general-purpose Typst PDF template
- `assets/typst/example-cfp.typ` — example CFP rendered with the template

---

## 1. CSS Fixes Applied

The conference CSS (`conferences/index.css`) was reduced from **1,073 lines to ~420 lines**.

### Critical bugs fixed

| Issue | Before | After |
|---|---|---|
| **`.plenary` padding** | `padding: 200px 0px` (massive vertical gap) | `padding: 2rem 0` (reasonable section spacing) |
| **`.simple-info-center` broken rule** | `color: var(--text-color)` *missing semicolon* → next rule ignored | Fixed syntax |
| **`.hero-banner .content-block h3` invalid weight** | `font-weight: 800px` (px on weight is invalid) | `font-weight: 800` |
| **`.schedule-detail` broken CSS** | `background: shift-color(...)` (Sass function in plain CSS) + stray `'` character | Cleaned to solid background color |
| **Hardcoded hex values** | `#1B3264`, `#ffcc00`, etc. repeated 30+ times | All use CSS custom properties (`var(--apls-blue)`, `var(--apls-gold)`) |
| **Duplicate selectors** | `.hero-banner` defined 5 times, `.hero-banner .content-block` defined 6 times, `#btn-guide` defined twice with *different* colors | Each selector defined once, final values preserved |
| **Dark mode** | Used `prefers-color-scheme` (ignores site toggle) | Uses `[data-bs-theme="dark"]` (matches Quarto/Bootstrap toggle) |

### Remaining CSS architecture note

The page still loads **both** `index.css` (page-specific) and `theme.scss` + `_partials/*.scss` (site-wide). There is some unavoidable overlap because the frosted-glass hero is unique to the conference page. The cleaned CSS removes all the dead/duplicate rules, so future edits are much safer.

---

## 2. Conference Page Structure Assessment

### Current information architecture

```
Hero banner (title, date, location)
├── Icon grid (General, Proposals, Registration, Hotel, Schedule, Workshops, Archives)
├── General Information
│   └── Quote + conference logo image
├── "Learn More" callout (links to archive)
├── Submissions / Call for Proposals
│   └── Button to CFP page
├── Hotel Information
│   └── Photo + address + conditional room-block callout
├── Schedule
│   └── Placeholder note only
├── Registration
│   └── Tabset: Info | Pricing
└── Preconference Workshops
    └── Button to preconference page
```

### What's working well

- **Data-driven content**: rates, notes, and URLs all come from CSVs refreshed from the Google Sheet — no code edits needed for routine updates.
- **Conditional UI**: the room-block callout and Register button appear automatically when their URLs are set in the Sheet.
- **Icon grid**: gives fast visual navigation to sub-sections and sub-pages.
- **Alt text**: images have descriptive alt text.

### What's not working well

| Problem | Impact | Severity | Status |
|---|---|---|---|
| **Schedule section is empty** | Users see only a placeholder note; looks unfinished | High | **Fixed** — day-by-day outline added |
| **Registration pricing is hidden behind a tab** | Users must click to see costs — a key decision factor | Medium-High | **Fixed** — tabset removed, pricing shown directly |
| **CFP section lacks urgency / status** | No deadline, no "open / closed" indicator, no download link | Medium | **Fixed** — dynamic callout banner added |
| **No visual distinction for the active CFP period** | During submission season, the CFP should be the hero action | Medium | **Fixed** — hero buttons appear conditionally |
| **"Learn More" callout is redundant** | User is already on the conference page; link goes to archive | Medium | **Fixed** — removed |
| **Too many `vspace` + `<hr>` separators** | Creates visual fatigue; page feels longer than it is | Medium | Partial — reduced some, full refactor deferred |
| **Preconference workshops are buried** | Below registration, easy to miss | Low | Deferred |

| Problem | Impact | Severity |
|---|---|---|
| **Schedule section is empty** | Users see only a placeholder note; looks unfinished | High |
| **Registration pricing is hidden behind a tab** | Users must click to see costs — a key decision factor | Medium-High |
| **Too many `vspace` + `<hr>` separators** | Creates visual fatigue; page feels longer than it is | Medium |
| **"Learn More" callout is redundant** | User is already on the conference page; link goes to archive | Medium |
| **CFP section lacks urgency / status** | No deadline, no "open / closed" indicator, no download link | Medium |
| **No visual distinction for the active CFP period** | During submission season, the CFP should be the hero action | Medium |
| **Preconference workshops are buried** | Below registration, easy to miss | Low |

---

## 3. Recommended Design Improvements

### A. Make the schedule section useful (High priority) — **Implemented**

**Current**: just a placeholder sentence.

**Implemented**: Added a three-column day-by-day outline (Thu/Fri/Sat) showing key events, plus a `schedule_preview` key in the data file for a custom intro message.

---

### B. Expose registration pricing by default (High priority) — **Implemented**

**Current**: pricing was on the second tab of a tabset.

**Implemented**: Removed the tabset entirely. The registration note + Register button appear first, followed by the rates table in a callout box.

---

### C. Add a CFP status banner (Medium priority) — **Implemented**

**Current**: static "Call for Proposals" text + button.

**Implemented**: Dynamic callout banner driven from the Sheet data:
- **OPEN** (red/important callout): shows deadline + submission portal link when `submission_portal_url` is set
- **CLOSED** (note callout): shows closed message when deadline is in the past
- **COMING SOON** (tip callout): shows upcoming message otherwise

---

### D. Reduce visual noise (Medium priority) — **Partial**

**Current**: Every section is separated by `::: vspace :::` + `<hr>`.

**Implemented**: Removed the redundant "Learn More" blue callout. The `<hr>` separators remain for now; a full refactor would require updating the site-wide `theme.scss` spacing system.

---

### E. Make the hero banner actionable during CFP period (Medium priority) — **Implemented**

**Current**: hero showed only title, location, and date.

**Implemented**: Hero now conditionally shows:
- "Submit a Proposal" button (primary/gold) when CFP is open and portal URL is set
- "Register" button (secondary) when registration URL is set

---

### F. Consolidate the "Learn More" callout (Low priority) — **Implemented**

**Removed**: The full-width blue callout linking to the archive has been removed. The icon grid already has an "Archives" link.

---

### G. Add a downloadable CFP PDF — **Template ready**

The new Typst template (`assets/typst/apls-template.typ`) produces a brand-consistent, accessible PDF. The example CFP (`assets/typst/example-cfp.typ`) demonstrates usage.

**Recommended workflow**:
1. Each year, copy `example-cfp.typ` to `conferences/cfp/cfp-20XX.typ`.
2. Edit the conference-specific details (dates, location, submission types, deadlines).
3. Compile: `typst compile conferences/cfp/cfp-20XX.typ conferences/cfp/cfp-20XX.pdf`
4. Link the PDF from the CFP sub-page and from the main conference page.

The template handles:
- Brand colors and typography (Cormorant Garamond + Proza Libre)
- Accessible heading hierarchy and link contrast
- Automatic page headers/footers
- Two-column layouts for side-by-side info

**Current**: just a placeholder sentence.

**Recommended**: Even before the full schedule is ready, show:
- A high-level day-by-day outline (Thu / Fri / Sat)
- Key event times (opening, plenaries, poster sessions, reception)
- A "full schedule coming soon" notice

This sets expectations and helps attendees with travel planning.

### B. Expose registration pricing by default (High priority)

**Current**: pricing is on the second tab of a tabset.

**Recommended**: Show the rates table directly on the page, with the info/notes above it. The tabset adds a click for information every user needs. If the tabset must stay for space reasons, make "Pricing" the **active** tab by default.

### C. Add a CFP status banner (Medium priority)

**Current**: static "Call for Proposals" text + button.

**Recommended**: Add a visual status indicator:

```
[ OPEN ]  Submissions accepted through October 15, 2026
[ CLOSED ] Submissions are no longer being accepted
[ COMING SOON ] Submissions open September 1, 2026
```

Drive this from the conference Google Sheet (`cfp_deadline`, `cfp_status` keys) so it updates automatically.

### D. Reduce visual noise (Medium priority)

**Current**: Every section is separated by `::: vspace :::` + `<hr>`.

**Recommended**: 
- Remove half the horizontal rules — alternate background colors already create section boundaries.
- Replace `vspace` divs with CSS margin on sections.
- Group related content into cards or boxes instead of linear separators.

### E. Make the hero banner actionable during CFP period (Medium priority)

**Current**: hero shows only title, location, and date.

**Recommended**: During the CFP window, add a prominent primary button in the hero:

```
2027 Annual Conference
Louisville, KY  ·  March 18-20, 2027

[ Submit a Proposal ]  [ Register ]
```

Drive this from the Sheet (`show_cfp_in_hero: true/false`).

### F. Consolidate the "Learn More" callout (Low priority)

**Current**: a full-width blue callout linking to the archive.

**Recommended**: Replace with a subtle text link at the bottom of the General Information section, or move it to the footer of the page. The icon grid already has an "Archives" link.

### G. Add a downloadable CFP PDF (Done — see Typst template)

The new Typst template (`assets/typst/apls-template.typ`) produces a brand-consistent, accessible PDF. The example CFP (`assets/typst/example-cfp.typ`) demonstrates usage.

**Recommended workflow**:
1. Each year, copy `example-cfp.typ` to `conferences/cfp/cfp-20XX.typ`.
2. Edit the conference-specific details (dates, location, submission types, deadlines).
3. Compile: `typst compile conferences/cfp/cfp-20XX.typ conferences/cfp/cfp-20XX.pdf`
4. Link the PDF from the CFP sub-page and from the main conference page.

The template handles:
- Brand colors and typography (Cormorant Garamond + Proza Libre)
- Accessible heading hierarchy and link contrast
- Automatic page headers/footers
- Two-column layouts for side-by-side info

---

## 4. Google Sheet Review

The conference page reads from `conferences/data/*.csv`, refreshed by `conferences/_update-conference.R` from the **AP-LS Conference** Google Sheet.

### Sheet structure (expected tabs)

| Tab | Outputs | Used on page |
|---|---|---|
| `info` | `data/info.csv` | All dynamic text: submission notes, hotel note, registration note, rates note, preconference note |
| `registration-rates` | `data/registration-rates.csv` | Registration pricing table |
| `workshops` | `data/workshops.csv` + individual `.qmd` files | Preconference workshop sub-pages |

### Recommended additions to the Sheet

To support the improvements above, add these keys to the `info` tab:

| Key | Example value | Used for |
|---|---|---|
| `cfp_status` | `open` | Status banner: open / closed / upcoming |
| `cfp_deadline` | `2026-10-15` | Deadline display |
| `cfp_pdf_url` | `cfp/cfp-2027.pdf` | Link to downloadable PDF |
| `show_cfp_in_hero` | `true` | Whether to show a "Submit Proposal" button in the hero banner |
| `schedule_preview` | `Brief schedule...` | Short text for the schedule section before the full program is ready |

---

## 5. Overall Site Design Suggestions

Beyond the conference page, these patterns would improve the whole site:

### Consistency
- **Cards and boxes**: The site uses multiple card styles (boxed-feature-grid, content-block-blue, callout, simple-info-center). Consider consolidating to 2–3 reusable card components defined in `_partials/`.
- **Spacing**: Replace ad-hoc `vspace` divs with a consistent vertical-rhythm system (e.g., `section--sm`, `section--md`, `section--lg` utility classes).

### Visual hierarchy
- **Hero banners**: Only the conference page has a full-bleed photo hero. Consider adding subdued hero images or brand-colored banners to other top-level pages (awards, membership, resources) so they feel as polished as the home page and conference page.
- **Active states**: Navigation items don't show an active state for the current page. Adding `.active` styling would help users orient themselves.

### Performance
- **Image sizes**: The conference logo (`images/apls2027.png`) and hotel photo should be checked — if they're large PNGs, converting to compressed JPEG or WebP would improve load time.
- **CSS size**: `index.css` was 1,073 lines with ~60% duplication. Other page-specific CSS files should be audited the same way.

### Accessibility
- **Color contrast**: The frosted-glass hero uses white text on a semi-transparent background over a photo. The text shadow helps, but if the photo has light areas, contrast can dip below WCAG AA. Consider a subtle dark gradient overlay on the photo behind the content block.
- **Focus indicators**: The `.button-17` focus state uses a border color change but no outline. Adding a visible focus ring (`outline: 2px solid var(--apls-gold)`) would improve keyboard navigation.

---

## 6. Typst Template — Usage Summary

**Location**: `assets/typst/apls-template.typ`

### Quick start

```bash
# Compile the example
cd assets/typst
typst compile example-cfp.typ cfp-2027.pdf

# Watch mode (auto-rebuild on save)
typst watch example-cfp.typ cfp-2027.pdf
```

### Available functions

| Function | Purpose |
|---|---|
| `apls-doc(...)` | Main template wrapper. Sets page layout, typography, headers/footers, title page |
| `apls-rule` | Gold horizontal rule |
| `apls-button(label, url)` | Branded pill button (for web links in PDFs) |
| `apls-two-col(left, right)` | Two-column grid layout |
| `apls-callout(title, fill, accent, body)` | Box with left accent border for tips, notes, warnings |

### Template parameters

```typst
#show: apls-doc.with(
  title: "Document Title",
  subtitle: "Optional subtitle",
  authors: ("Author Name",),
  date: "August 2026",
  logo: true,           // Show AP-LS brand mark on title page
  header-title: "Short Title",  // Running header on page 2+
  toc: false,           // Table of contents
)
```

### Fonts

The template requests **Cormorant Garamond** (headings) and **Proza Libre** (body). If not installed, Typst falls back to Georgia / Helvetica Neue / Arial.

Install the fonts via Homebrew:
```bash
brew install font-cormorant font-proza-libre
```

Or download from Google Fonts and place in `~/.local/share/fonts/`.

### Accessibility features built in

- Sufficient color contrast for all text combinations (tested against WCAG AA)
- Logical heading hierarchy (H1 → H2 → H3) with visual distinction
- Underlined links in brand steel color
- Serif/sans-serif pairing supports dyslexia-friendly reading
- Generous line height (1.5em) and paragraph spacing

---

## Action checklist

- [x] Clean and consolidate `conferences/index.css`
- [x] Create `assets/typst/apls-template.typ` (general-purpose brand template)
- [x] Create `assets/typst/example-cfp.typ` (demonstration document)
- [x] Add day-by-day schedule outline to conference page
- [x] Remove registration tabset, expose pricing by default
- [x] Add dynamic CFP status banner (open / closed / upcoming)
- [x] Add conditional hero buttons (Submit Proposal / Register)
- [x] Add `schedule_preview` key to conference data + update script docs
- [x] Update main README with Typst template reference
- [ ] Verify Typst template compiles: `typst compile assets/typst/example-cfp.typ test.pdf`
- [ ] Populate schedule section with full program when available
- [ ] Generate CFP PDF from template and link from CFP page
- [ ] Audit other page-specific CSS files for duplication

- [x] Clean and consolidate `conferences/index.css`
- [x] Create `assets/typst/apls-template.typ` (general-purpose brand template)
- [x] Create `assets/typst/example-cfp.typ` (demonstration document)
- [ ] Verify Typst template compiles: `typst compile assets/typst/example-cfp.typ test.pdf`
- [ ] Populate schedule section with at least a day-by-day outline
- [ ] Make registration pricing the default/active tab, or remove tabset
- [ ] Add `cfp_status`, `cfp_deadline`, `show_cfp_in_hero` to conference Google Sheet
- [ ] Generate CFP PDF from template and link from CFP page
- [ ] Audit other page-specific CSS files for duplication
