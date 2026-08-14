![Logo for American Psychology-Law Society](images/APLS_general_logo.png)

# AP-LS Website

This repository contains the source for [ap-ls.org](https://ap-ls.org), the website of the American Psychology-Law Society (AP-LS), Division 41 of the American Psychological Association.

The site is built with [Quarto](https://quarto.org) and R. Most routine updates (job postings, award winners, carousel images, leadership) do **not** require writing any code — they are small edits to `.yml` data files or `.qmd` text files, or updates to a Google Sheet.

## How the site works:

1. Pages are `.qmd` files.
2. Frequently changing content (jobs, awards, leadership, carousel) lives in `.yml` and `.csv` data files, so pages rarely need to be edited directly.
3. Some data files are generated from Google Sheets on the AP-LS Google Drive.
4. Shared R helpers (carousels, tables, card grids) live in the `aplsr` package in `apls-r/`.
5. Quarto renders everything into the `docs/` folder, which is what gets published.

## Technical things

The repository lives in the [American-Psychology-Law-Society](https://github.com/American-Psychology-Law-Society/apls-org) GitHub organization. Editors commit and push to the `main` branch. Netlify then publishes the committed `docs/` folder automatically, and the update appears at [ap-ls.org](https://ap-ls.org).

The domain name is managed through the organization's Google enterprise account, which is maintained by the AP-LS office. Domain questions go to [office@ap-ls.org](mailto:office@ap-ls.org).

## Getting access and getting set up

Access to the repository is granted by the web editor — email [webeditor@ap-ls.org](mailto:webeditor@ap-ls.org). Then:

```bash
git clone https://github.com/American-Psychology-Law-Society/apls-org.git
```

You need R, RStudio, and Quarto installed. Once, in R:

```r
renv::restore()          # install the pinned package versions
renv::install("./apls-r") # install the site's own aplsr package
# or use pak to install local copy for now -- will update to cloud stable version eventually
```

> [!WARNING]
> Always preview the whole site with plain `quarto preview`. Never preview a single page (`quarto preview index.qmd`): pages that list other pages come out empty, and the broken output lands in `docs/`.

## Where the detailed documentation lives

The **AP-LS Webeditor Guide** is the full handbook: setup details, a Quarto primer, a map of every site section, step-by-step recipes for common tasks, the Google Sheets pipelines, the conference-year workflow, the `aplsr` package reference, the brand style guide, accessibility checks, and troubleshooting. It lives in its own repository, [American-Psychology-Law-Society/website-guide](https://github.com/American-Psychology-Law-Society/website-guide), and is published on the organization's GitHub Pages.

## The rules that matter most

- Edit the data files and page text, never the generated output: do not edit anything in `docs/` or `_freeze/` by hand.
- Preview the whole site, never a single page.
- Do not rename or move files casually — pages link to each other by path.
- Do not rename Google Sheet tabs or column headers; the update scripts and some pages depend on them.
- Build clean before you push: `Rscript scripts/build-site.R` renders the site and runs the accessibility and link checks in one pass.

## Getting help

Email [webeditor@ap-ls.org](mailto:webeditor@ap-ls.org) or [report an issue](https://docs.google.com/forms/d/e/1FAIpQLSfOL2JsE-YbvqH09-S6zcukZ6qiOycK98DjXa08MDygMTWBYA/viewform?usp=sf_link).
