# AP-LS Typst template

Use `apls-template.typ` to create AP-LS-branded PDFs. `example-cfp.typ` shows the template in use.

## Compile

Install Typst (macOS: `brew install typst`), then from this folder:

```sh
typst compile example-cfp.typ cfp.pdf
```

Brand fonts are optional; without them Typst uses fallback fonts.

## Use in a document

```typst
#import "apls-template.typ": apls-doc, apls-button, apls-rule, apls-two-col

#show: apls-doc.with(
  title: "Document title",
  subtitle: none,
  authors: ("Author",),
  date: "October 2026",
  logo: true,
  header-title: "Short title",
  toc: false,
)

= Introduction
Content here.
```

Available helpers: `apls-button(label, url)`, `apls-rule`, and `apls-two-col(left, right)`. Keep assets beside the `.typ` file and reference them with relative paths. Keep template options and helpers documented here in sync with `apls-template.typ`.
