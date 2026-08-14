// AP-LS Brand Template for Typst
// ================================
// A general-purpose, accessible document template for the American
// Psychology-Law Society. Uses the official brand colors, typography,
// and spacing conventions defined in _brand.yml.
//
// USAGE
// -----
//   #import "apls-template.typ": apls-doc, apls-rule, apls-button, apls-two-col, apls-callout
//   #show: apls-doc.with(
//     title: "Document Title",
//     subtitle: "Optional subtitle",
//     authors: ("Author Name",),
//     date: "August 2026",
//     logo: true,
//     header-title: "Short Title",
//   )
//   #lorem(100)
//
// FONTS
// -----
// The template requests Cormorant Garamond (headings) and Proza Libre
// (body). If these are not installed, Typst falls back to system fonts.
// Install the brand fonts via:
//   brew install font-cormorant font-proza-libre font-lato
// Or download from Google Fonts and place in ~/.local/share/fonts/.

// ── Brand Palette ─────────────────────────────────────────────────────
#let apls-blue       = rgb("#1B3264")
#let apls-steel      = rgb("#4271B3")
#let apls-cream      = rgb("#FBF9F4")
#let apls-gold       = rgb("#ffcc00")
#let apls-dark-bg    = rgb("#191E29")
#let apls-dark-light = rgb("#E1E8F5")
#let apls-gray       = rgb("#737475")

// ── Font Configuration ────────────────────────────────────────────────
#let font-heading = ("Cormorant Garamond", "Georgia", "Times New Roman", "serif")
#let font-body    = ("Proza Libre", "Helvetica Neue", "Arial", "sans-serif")
#let font-mono    = ("Menlo", "Consolas", "Courier New", "monospace")

// ── Reusable Components ───────────────────────────────────────────────

// A gold-accented horizontal rule
#let apls-rule = line(length: 100%, stroke: 1pt + apls-gold)

// A branded button-like link
#let apls-button(label, url) = {
  box(
    inset: (x: 1.2em, y: 0.5em),
    radius: 4pt,
    fill: apls-blue,
    text(fill: apls-cream, weight: "bold", size: 10pt, link(url)[#label]),
  )
}

// A two-column layout helper
#let apls-two-col(left, right, gutter: 2em) = {
  grid(
    columns: (1fr, 1fr),
    column-gutter: gutter,
    left, right,
  )
}

// A callout box for tips, notes, warnings
#let apls-callout(title: none, fill: apls-cream, accent: apls-steel, body) = {
  block(
    width: 100%,
    inset: (left: 1em, right: 1em, top: 0.8em, bottom: 0.8em),
    stroke: (left: 4pt + accent),
    fill: fill,
    radius: (top-right: 4pt, bottom-right: 4pt),
    {
      if title != none {
        text(font: font-heading, weight: "bold", size: 12pt, fill: apls-blue, title)
        v(0.4em)
      }
      body
    },
  )
}

// ── Template Function ─────────────────────────────────────────────────
#let apls-doc(
  title: none,
  subtitle: none,
  authors: (),
  date: none,
  logo: true,
  header-title: none,
  toc: false,
  body,
) = {
  // ── Page Setup ──────────────────────────────────────────────────────
  set page(
    paper: "us-letter",
    margin: (top: 1.2in, bottom: 1in, left: 1in, right: 1in),
    header: context {
      if counter(page).get().first() > 1 {
        let ht = header-title
        if ht == none { ht = title }
        align(right, text(
          size: 9pt,
          fill: apls-gray,
          font: font-body,
          smallcaps(ht),
        ))
        line(length: 100%, stroke: 0.5pt + apls-gray.lighten(50%))
      }
    },
    footer: context {
      if counter(page).get().first() > 1 {
        line(length: 100%, stroke: 0.5pt + apls-gray.lighten(50%))
        grid(
          columns: (1fr, auto, 1fr),
          align(left, text(size: 8pt, fill: apls-gray, "American Psychology-Law Society")),
          align(center, text(size: 8pt, fill: apls-gray, counter(page).display("1"))),
          align(right, text(size: 8pt, fill: apls-gray, "ap-ls.org")),
        )
      }
    },
  )

  // ── Typography ──────────────────────────────────────────────────────
  set text(
    font: font-body,
    size: 11pt,
    fill: apls-blue,
    lang: "en",
    region: "US",
  )

  set par(
    justify: true,
    leading: 1.5em,
    spacing: 1.2em,
  )

  set heading(numbering: "1.1.")

  show heading: it => {
    let color = apls-blue
    let weight = "bold"
    let font-size = 11pt
    let above = 1.5em
    let below = 0.8em

    if it.level == 1 {
      font-size = 18pt
      weight = "bold"
      above = 2em
      below = 1em
      block(above: above, below: below, {
        text(font: font-heading, size: font-size, weight: weight, fill: color, it)
        v(0.3em)
        line(length: 100%, stroke: 2pt + apls-gold)
      })
    } else if it.level == 2 {
      font-size = 14pt
      weight = "bold"
      above = 1.5em
      below = 0.6em
      block(above: above, below: below, {
        text(font: font-heading, size: font-size, weight: weight, fill: color, it)
      })
    } else {
      font-size = 12pt
      weight = "bold"
      above = 1.2em
      below = 0.4em
      block(above: above, below: below, {
        text(font: font-body, size: font-size, weight: weight, fill: color, it)
      })
    }
  }

  // ── Lists ───────────────────────────────────────────────────────────
  set list(
    marker: (text(fill: apls-steel, "•"), text(fill: apls-steel, "◦")),
    indent: 1.5em,
  )
  set enum(
    numbering: "1.",
    indent: 1.5em,
  )

  // ── Links ───────────────────────────────────────────────────────────
  show link: it => {
    text(fill: apls-steel, underline(it))
  }

  // ── Code / Raw ──────────────────────────────────────────────────────
  show raw: it => {
    text(font: font-mono, size: 9.5pt, fill: apls-dark-bg, it)
  }

  // ── Block Quotes ────────────────────────────────────────────────────
  show quote: it => {
    block(
      width: 100%,
      inset: (left: 1.5em, right: 1em, top: 0.5em, bottom: 0.5em),
      stroke: (left: 4pt + apls-gold),
      fill: apls-cream.darken(5%),
      text(style: "italic", it.body),
    )
  }

  // ── Tables ──────────────────────────────────────────────────────────
  set table(
    stroke: (x, y) => {
      if y == 0 {
        (bottom: 2pt + apls-blue)
      } else {
        (bottom: 0.5pt + apls-gray.lighten(60%))
      }
    },
    fill: (x, y) => {
      if y == 0 { apls-blue }
      else { none }
    },
  )
  show table.cell: it => {
    if it.y == 0 {
      text(fill: apls-cream, weight: "bold", font: font-body, it)
    } else {
      text(fill: apls-blue, font: font-body, it)
    }
  }

  // ── Title Page ──────────────────────────────────────────────────────
  if title != none {
    page(margin: (top: 1.5in, bottom: 1in, left: 1in, right: 1in), {
      // Top accent bar
      place(top, line(length: 100%, stroke: 6pt + apls-gold))

      v(2em)

      // Logo placeholder or brand mark
      if logo {
        align(center, {
          text(
            font: font-heading,
            size: 28pt,
            weight: "bold",
            fill: apls-blue,
            "AP-LS",
          )
          v(-0.3em)
          text(
            font: font-body,
            size: 10pt,
            fill: apls-gray,
            smallcaps("American Psychology-Law Society"),
          )
        })
        v(2em)
      }

      // Title
      align(center, {
        text(font: font-heading, size: 26pt, weight: "bold", fill: apls-blue, title)
        v(0.5em)
        if subtitle != none {
          text(font: font-body, size: 14pt, fill: apls-steel, subtitle)
          v(0.5em)
        }
      })

      v(1.5em)

      // Decorative line
      align(center, line(length: 40%, stroke: 1.5pt + apls-gold))

      v(1.5em)

      // Authors and date
      align(center, {
        if authors.len() > 0 {
          text(font: font-body, size: 12pt, fill: apls-blue, authors.join(", "))
          v(0.5em)
        }
        if date != none {
          text(font: font-body, size: 11pt, fill: apls-gray, date)
        }
      })

      v(1fr)

      // Footer brand bar
      align(center, {
        line(length: 60%, stroke: 0.5pt + apls-gray.lighten(50%))
        v(0.5em)
        text(font: font-body, size: 9pt, fill: apls-gray, "ap-ls.org  ·  Division 41 of the American Psychological Association")
      })
    })
  }

  // ── Optional Table of Contents ──────────────────────────────────────
  if toc {
    outline(
      title: text(font: font-heading, size: 16pt, weight: "bold", fill: apls-blue, "Contents"),
      indent: auto,
    )
    pagebreak()
  }

  // ── Main Body ───────────────────────────────────────────────────────
  body
}
