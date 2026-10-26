# AP-LS website

Quarto and R source for [ap-ls.org](https://ap-ls.org). Edit `.qmd`, data, and source assets; `docs/` and `_freeze/` are generated output.

## Build and publish

Install R, RStudio, and Quarto. From the project root, restore dependencies and install the local helper package:

```r
renv::restore()
renv::install("./apls-r")
```

Preview and build the whole site; single-page previews can leave broken output in `docs/`:

```sh
quarto preview
Rscript scripts/build-site.R
```

Commit and push to `main`; Netlify publishes `docs/`. Do not edit generated output by hand.

## Data workflows

- Conference Sheet: `source("conferences/_update-conference.R")` from the project root.
- Google Sheet imports and review-document functions: see `apls-r/README.md` and the relevant `automation/*/README.md`.
- New conference year: follow `conferences/_template/README.md`; create a Sheet from `conferences/sheet-id/README.md` if needed.

Keep Google Sheet tab names and column headers unchanged; scripts depend on them. Avoid renaming or moving linked pages and assets.

For repository access, contact [webeditor@ap-ls.org](mailto:webeditor@ap-ls.org).
