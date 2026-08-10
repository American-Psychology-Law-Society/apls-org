![Logo for American Psychology-Law Society](images/APLS_general_logo.png)

# AP-LS Website

This repository contains the source for [ap-ls.org](https://ap-ls.org), the website of the American Psychology-Law Society (AP-LS), Division 41 of the American Psychological Association.

The site is built with [Quarto](https://quarto.org) and R. Most routine updates (job postings, award winners, carousel images, leadership) do **not** require writing any code — they are small edits to `.yml` data files or `.qmd` text files, or updates to a Google Sheet.

**→ Want to update the site? Start here: [UPDATING.md](UPDATING.md)**

That guide is written for editors of all technical levels, including people who have never used R or Quarto.

> [!WARNING]
> Always preview the whole site with plain `quarto preview`. Never preview a single page (`quarto preview index.qmd`): pages that list other pages come out empty, and the broken output lands in `docs/`. See [What not to do](UPDATING.md#what-not-to-do).

## How the site works (30-second version)

1. Pages are `.qmd` files (Markdown + optional R code).
2. Frequently changing content (jobs, awards, leadership, carousel) lives in `.yml` and `.csv` data files, so pages rarely need to be edited directly.
3. Some data files are generated from Google Sheets on the AP-LS Google Drive by small R scripts (see [UPDATING.md](UPDATING.md#content-that-comes-from-google-drive)).
4. Shared R helpers (carousels, tables) live in the `aplsr` package in `apls-r/`; pages load them with `library(aplsr)`.
5. Quarto renders everything into the `docs/` folder, which is what gets published.

## Repository layout

| Path | What it is |
|---|---|
| `_quarto.yml` | Site-wide configuration: navigation, footer, theme, search |
| `_brand.yml` | Brand colors and fonts (light + dark mode); edit colors here |
| `_variables.yml` | Reusable text snippets (emails, social links) via shortcodes |
| `theme.scss` + `_partials/` | Custom styling on top of the brand (SCSS) |
| `index.qmd` | Home page |
| `about/`, `awards/`, `conferences/`, `membership/`, `newsletter/`, `publications/`, `resources/` | Site sections; each section's main page is its `index.qmd` |
| `apls-r/` | The `aplsr` R package: shared helpers used by pages |
| `assets/` | Static assets: favicons, CSL citation style |
| `images/` | Site-wide images (logos, banners, carousel) |
| `_extensions/`, `_filters/` | Quarto extensions and Lua filters |
| `docs/` | Rendered site (build output; do not edit by hand) |
| `renv.lock`, `renv/` | Pinned R package versions for reproducible builds |

## For developers

- R package versions are pinned with `renv`. After cloning: `renv::restore()`, then `renv::install("./apls-r")` to install the local `aplsr` package.
- `Rscript scripts/build-site.R` renders the whole site and runs the accessibility and link checks in one pass. See [UPDATING.md](UPDATING.md#build-and-check-with-one-command).
- Pages that execute R code are frozen (`freeze: auto` in `_quarto.yml`); Quarto only re-executes pages whose source changed.
- Styling rules: define colors in `_brand.yml`, not in `theme.scss` or inline styles — hardcoded values break dark mode. See the comments at the top of `theme.scss`.
- The `aplsr` package has its own tests (`apls-r/tests/`) and documentation (`apls-r/vignettes/getting-started.qmd`).
