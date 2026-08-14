# AP-LS Typst Template

A general-purpose, accessible document template for the American Psychology-Law Society. Produces brand-consistent PDFs using the official AP-LS colors, typography, and spacing.

## Files

| File | Purpose |
|---|---|
| `apls-template.typ` | The template itself — import this into your document |
| `example-cfp.typ` | Example: a Call for Proposals rendered with the template |

## Quick Start

### 1. Install Typst

```bash
brew install typst
```

### 2. Install brand fonts (optional but recommended)

```bash
brew install font-cormorant font-proza-libre font-lato
```

If the fonts are not installed, Typst falls back to Georgia / Helvetica.

### 3. Compile an example

```bash
cd assets/typst
typst compile example-cfp.typ cfp-2027.pdf
```

Or use watch mode for live preview while editing:

```bash
typst watch example-cfp.typ cfp-2027.pdf
```

## Using the Template

```typst
#import "apls-template.typ": apls-doc, apls-button, apls-rule

#show: apls-doc.with(
  title: "Your Document Title",
  subtitle: "Optional Subtitle",
  authors: ("Author One", "Author Two"),
  date: "August 2026",
  logo: true,              // show AP-LS brand mark on title page
  header-title: "Short Title for Running Header",
  toc: true,               // include table of contents
)

= Introduction

Your content here.
```

## Template Options

| Option | Type | Default | Description |
|---|---|---|---|
| `title` | `string` | `none` | Document title (required) |
| `subtitle` | `string` | `none` | Subtitle shown below title |
| `authors` | `array` | `()` | List of author names |
| `date` | `string` | `none` | Date string |
| `logo` | `bool` | `true` | Show AP-LS brand mark on title page |
| `header-title` | `string` | `none` | Short title for running header |
| `toc` | `bool` | `false` | Include table of contents |

## Exported Helpers

Import these alongside the template for common patterns:

```typst
#import "apls-template.typ": apls-button, apls-rule, apls-two-col

#apls-button("Register Now", "https://ap-ls.org/")

#apls-rule  // gold accent line

#apls-two-col([Left column content], [Right column content])
```

## Accessibility Features

- **Contrast**: Body text uses AP-LS Blue (#1B3264) on Cream (#FBF9F4) — ratio ~12:1 (WCAG AAA)
- **Heading hierarchy**: Clear visual distinction between H1, H2, H3 with numbered sections
- **Tagged PDF**: Typst 0.14+ generates tagged PDFs automatically for screen readers
- **Semantic markup**: Tables have proper header rows, lists use high-contrast bullets

## Brand Colors Used

| Token | Hex | Usage |
|---|---|---|
| AP-LS Blue | `#1B3264` | Body text, headings, primary fills |
| AP-LS Steel | `#4271B3` | Links, secondary accents, bullets |
| AP-LS Gold | `#ffcc00` | Accent rules, heading underlines, highlights |
| AP-LS Cream | `#FBF9F4` | Page background, title page |
| AP-LS Gray | `#737475` | Footer text, muted elements |

## Tips

- **Images**: Place images in the same directory as your `.typ` file and reference them with relative paths: `#image("logo.png", width: 60%)`
- **Math**: Typst has built-in math rendering: `$x = (-b plus.minus sqrt(b^2 - 4 a c)) / (2 a)$`
- **Bibliography**: Add a `.bib` file and use `#bibliography("refs.bib")` for automatic citation formatting
- **Multi-page**: The template automatically adds running headers/footers after the title page
