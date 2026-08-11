![Logo for American Psychology-Law Society](images/APLS_general_logo.png)

# AP-LS Website

This repository contains the source for [ap-ls.org](https://ap-ls.org), the website of the American Psychology-Law Society (AP-LS), Division 41 of the American Psychological Association.

The site is built with [Quarto](https://quarto.org) and R. Most routine updates (job postings, award winners, carousel images, leadership) do **not** require writing any code — they are small edits to `.yml` data files or `.qmd` text files, or updates to a Google Sheet.

This guide is written for editors of all technical levels, including people who have never used R or Quarto.

> [!WARNING]
> Always preview the whole site with plain `quarto preview`. Never preview a single page (`quarto preview index.qmd`): pages that list other pages come out empty, and the broken output lands in `docs/`. See [What not to do](#what-not-to-do).

## How the site works (30-second version)

1. Pages are `.qmd` files (Markdown + optional R code).
2. Frequently changing content (jobs, awards, leadership, carousel) lives in `.yml` and `.csv` data files, so pages rarely need to be edited directly.
3. Some data files are generated from Google Sheets on the AP-LS Google Drive by small R scripts.
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

---

## Getting a local copy of the website

The whole website is one folder of files. Ask the web editor ([webeditor@ap-ls.org](mailto:webeditor@ap-ls.org)) for a current copy. It can be shared as a zip file on Google Drive.

Unzip it somewhere you will keep it, such as `~doc/apls-org`. That folder is your working copy. Keep the folder structure intact: pages link to each other by path, so renaming or moving files can break links.

## First time local setup

About 30 minutes, once per device:

1. **Install R**: download from <https://cloud.r-project.org>
2. **Install RStudio**: download from <https://posit.co/download/rstudio-desktop/>
3. **Install Quarto**: download from <https://quarto.org/docs/get-started/>
4. **Open the project**: double-click `apls-org.Rproj` in the website folder.
5. **Install the R packages** (run once in the RStudio Console):
   ```r
   install.packages("renv")   # if needed
   renv::restore()            # installs the exact package versions the site uses
   renv::install("./apls-r")  # installs the site's own helper package
   ```
6. **Preview the site** (in the RStudio Terminal tab):
   ```bash
   quarto preview
   ```
   This opens the site in your browser and auto-refreshes when you save a file.

## Making and previewing edits

1. Find the file you need (the cookbook below lists which file holds which content). Content that changes often lives in `.yml` files (job postings, carousel slides, leadership) or `.csv` files (award winners). Edit those, not the `.qmd` page that displays them.
2. Make your edit in RStudio or any text editor and save.
3. Watch the change in `quarto preview`.
4. When it looks right, render the page so the built site in `docs/` is up to date:
   ```bash
   quarto render path/to/page.qmd
   ```
   (or `quarto render` with no arguments to rebuild the whole site)
5. Send the updated files back to the web editor (see [How changes reach the live site](#how-changes-reach-the-live-site)).

> **Before a large edit, DO NOT FORGET TO make a local backup.** Copy the file to a folder outside the website folder first. If something goes wrong, copy it back. (Don't leave backup copies inside the website folder; stray `.qmd` files will get picked up by the site build. If you want to create a 'draft' page before actually deploying it, see the Quarto built in draft options.)

### What not to do

A few shortcuts cause real damage. Avoid all of these:

- **Do not preview a single page** with `quarto preview path/to/page.qmd`. Always run plain `quarto preview` with no file name. Previewing one page builds it without the rest of the site around it. Pages that list other pages (the home page's e-news cards, the job postings, the newsletter index) come out empty, and that broken output lands in `docs/`. If it happens to you, see [Troubleshooting](#troubleshooting).
- **Do not edit anything inside `docs/` or `_freeze/`.** Those folders are built output. Quarto regenerates them from the `.qmd` sources on every render, so edits there are lost anyway, and hand edits can fight the build. Make every change in the source files, then render.
- **Do not rename or move files and folders.** Pages link to each other by path. A renamed file breaks every link that points at it, including ones on pages you did not touch.
- **Do not commit or hand off right after a failed or interrupted render.** If a render stops partway, `docs/` can hold a half-built mix of old and new pages. Render again until it finishes cleanly, or run `Rscript scripts/build-site.R`, which checks the result for you.

---

## Content that comes from Google Drive

Several pages are fed by Google Sheets on the AP-LS Google Drive. **All of these Sheets must stay shared as "anyone with the link can view"**; the update scripts read them without logging in.

| Google Sheet | Feeds | How updates reach the site |
|---|---|---|
| [AP-LS Award Winners](https://docs.google.com/spreadsheets/d/1QZ2IU2gI5Fj91LX3coIoVXHWHWExOVuL3wb3IHu1cvE) | Past-recipients tables on `awards/` pages | Run `awards/_update-awards.R` (see [cookbook](#update-award-winners)) |
| [EC Leadership](https://docs.google.com/spreadsheets/d/16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8) | `about/leadership.qmd` (officers, conference chairs); also committee chairs on `about/committees.qmd` | Run `about/_update-ec.R`, then render |
| [Committees](https://docs.google.com/spreadsheets/d/17aXj7E4OE-vIgnRkNVZyw8BBjJ1MoXuroS71IqJ9rsI) | `about/committees.qmd` | Read when the page renders; just re-render the page |
| [Presidents](https://docs.google.com/spreadsheets/d/1iCz2Pss5GxP5J6G-3xA_-ePW-a6RQ4_fgRYvyrpYJTs) | `about/presidents/presidents.qmd` | Read when the page renders; just re-render the page |
| [Telepsychology](https://docs.google.com/spreadsheets/d/1TkZuOhtjY3zBJN8tTpwquXZKIuu1oalDAVNvXVDDDUo) | `resources/telepsychology/` | Read when the page renders; just re-render the page |
| [Campus reps](https://docs.google.com/spreadsheets/d/1zecpafvxt8XaHmJvhIFAB7_a7G3EDRPPuFNf2h3OiG8) | `resources/students/campus_reps.qmd` | Linked directly; no site update needed |

Two update patterns are in use:

- **Script-generated files (awards, leadership).** An R script copies the Sheet into `.csv`/`.yml` files saved in the website folder. The site build never touches Google, so the site can't break if Google is unreachable, but you must re-run the script when the Sheet changes.
- **Read at render time (committees, presidents, telepsychology).** The page pulls the Sheet each time it is *rendered*. Editing the Sheet does nothing until someone re-renders that page.

> **Renaming tabs or columns in a Sheet will break its update script or page.** If you must rename something, update the mapping in the corresponding script (`tabs` list in `awards/_update-awards.R`, or the code at the top of the `.qmd`).

---

## Common tasks cookbook

### Add or remove a job posting

Files: `resources/job-postings/academic-jobs.yml` and `resources/job-postings/professional-jobs.yml`

Add a new entry at the **top** of the file, following the existing format:

```yaml
- title: Assistant Professor of Psychology
  date: 2026-08-01
  organization: University of Nebraska, Department of Psychology
  location: Lincoln, Nebraska
  url: https://unl.example.com/
```

Then render `resources/job-postings/index.qmd` so the change appears in `docs/`.

### Change the home-page carousel

1. Save the image into `images/` (keep it small, under ~300 KB; see [image guidelines](#image-guidelines)).
2. Add an entry to `carousel.yml`:
   ```yaml
   - caption: "2027 AP-LS Call for Conference Proposals!"
     image: "images/2027_call_for_proposals.png"
     link: "https://ap-ls.org/conferences/"
   ```
3. Render `index.qmd`.

### Update award winners

1. Edit the **AP-LS Award Winners** Google Sheet (one tab per award).
2. In RStudio, from the project root, run:
   ```r
   source("awards/_update-awards.R")
   ```
   The script rewrites the CSVs in `awards/data/`. It will warn and skip a tab rather than overwrite a good CSV with an empty pull.
3. Open one of the changed CSVs and spot-check a few rows. Then render the affected award pages.

> Keep the book award's `year` column formatted as **plain text** in the Sheet (values like "2025a" or "2009-10" must survive).

### Update leadership (executive committee / conference chairs)

1. Edit the **EC Leadership** Google Sheet (tabs: `EC`, `Conf_Chairs`).
2. Run `source("about/_update-ec.R")` in RStudio; this rewrites `about/executive-committee.yml` and `about/conf-chairs.yml`.
3. President photos: name the file `firstname_lastname.png` (lowercase) and save it in `about/presidents/imgs/`; the script picks it up automatically.
4. Render `about/leadership.qmd`.

### Update committees

Edit the **Committees** Google Sheet, then re-render `about/committees.qmd`. No script needed.

### Update conference info from the Google Sheet

The conference pages take their changing facts (announcement notes,
deadlines, booking and registration links, rates, and workshops) from the
**AP-LS Conference** Google Sheet, the same pattern as award winners.

1. Edit the Sheet. Its tabs and columns are documented in the header
   comments of `conferences/_update-conference.R`. (If the Sheet does not
   exist yet, `conferences/sheet-seed/` has import-ready CSVs and a
   walkthrough for creating it, then paste its ID into the script.)
2. Run `source("conferences/_update-conference.R")` from the project root.
   It rewrites `conferences/data/*.csv` and builds one page per workshop in
   `conferences/preconference/`. It warns instead of overwriting a good CSV
   with an empty pull.
3. Spot-check with `git diff conferences/`, then render the conference
   pages.

Notes worth knowing: setting `hotel_booking_url` makes the room-block
booking callout appear on the main page, and setting `registration_url`
adds the Register button, no page edits needed. The committed CSVs are
what the site renders, so the build never depends on Google being
reachable.

### Start a new conference year

The conference pages come from a template in `conferences/_template/`. That
folder never publishes; it exists only to be copied. The short version:

1. Move the current year's files (`conferences/index.qmd`, `index.css`,
   `images/`, `data/`, `cfp/`, `preconference/`) into
   `conferences/archive/` under the year that ended, and point the archived
   page's two archive links back at the current page.
2. Copy the contents of `conferences/_template/` into `conferences/`.
3. Replace the placeholders (`20XX`, `CITY, ST`, hotel and link
   placeholders) in the copied `.qmd` files and in the seed CSVs in
   `data/`; "Replace in Files" handles each one in a single pass.
4. Update the Google Sheet for the new year and run
   `source("conferences/_update-conference.R")`.

The call for proposals and the preconference workshops are sub-pages
(`cfp/`, `preconference/`) so each can be updated on its own schedule. The
full walkthrough is in `conferences/_template/README.md`.

Conference co-chairs have their own guide in `conference-guide/`, a
standalone Quarto book that walks through the conference year from their
perspective. A rendered copy is at `conference-guide/_book/index.html`;
rebuild it with `quarto render conference-guide` after editing its pages.

### Add a monthly e-news issue (automated)

1. In Gmail, open the **individual newsletter email** (not the inbox view).
2. Use **File → Save Page As → Webpage, HTML Only**.
3. Drop the saved `.html` file into `resources/newsletter/_new_newsletters/`.
4. From the project root, run:
   ```bash
   Rscript scripts/process-newsletters.R
   ```
   This orchestrates the pipeline:
   - `scripts/extract_newsletter.R` extracts the newsletter body, strips recipient-identifying info, and saves the leading photo as `logo.png`
   - `scripts/html_to_pdf.R` generates a PDF for archiving
   - Creates `index.qmd` and cleaned HTML in `resources/newsletter/e-news/YYYY/monYYYY/`
5. Render `resources/newsletter/index.qmd` and `index.qmd` (the home page shows the three newest issues).

### Edit text on a page

Page text is plain Markdown inside each `.qmd` file. Everything below the second `---` line is content; edit it like a Word document (headings use `##`, links use `[text](url)`). Avoid changing the YAML block between the `---` lines unless you know what the field does.

### Image guidelines

Large images are the site's biggest speed problem. Before adding an image:

- Resize to the width it will actually display (usually ≤ 1600 px, thumbnails ≤ 800 px).
- Compress PNG/JPEG with a tool like <https://squoosh.app> (free, no install). Target: under 300 KB.
- Use descriptive lowercase filenames: `2027_conference_venue.png`, not `IMG_4032.PNG`.
- Adding a large PDF (e.g. an e-news issue)? Compress it first with ghostscript or ask the web editor.
- Bulk job? The website folder has `scripts/optimize-media.sh <dir>` (needs `gs`, `magick`, `pngquant`) which shrinks PDFs and images in place.

---

## How changes reach the live site

- The built site lives in the `docs/` folder. That folder is what gets published.
- You never publish directly. When your edits are ready and rendered, zip the website folder (or just the files you changed, keeping their folder structure) and share it with the web editor, for example on Google Drive. The web editor puts the new version live.
- Because all your work happens in your local copy, the live site cannot break while you experiment. If the preview looks wrong, keep fixing before you hand anything off.

Pages are "frozen" (`freeze: auto` in `_quarto.yml`): Quarto only re-executes R code on pages whose source changed. If you changed a data file but the page didn't update, render that page explicitly.

---

## Build and check with one command

For a full rebuild with verification, run from the project root:

```bash
Rscript scripts/build-site.R
```

This pulls the conference Google Sheet, renders the whole site, and runs the accessibility and link checks described below. It ends with a summary that tells you whether everything passed, printing the details of anything that needs attention. Use it before handing off a batch of changes. For one quick page, `quarto render path/to/page.qmd` is still faster.

### Handoff checklist

Before you zip the folder for the web editor or push your changes:

1. Run `Rscript scripts/build-site.R`.
2. Confirm it ends with "Build finished. Everything passed." If a check flags something, fix it and run the script again.
3. Skim the pages you changed in the browser, in both light and dark mode if you touched any styling.
4. Hand off as usual.

---

## Scripts reference

Scripts in `scripts/` are run from the project root.

| Script | What it does |
|---|---|
| `scripts/build-site.R` | Full rebuild: updates conference data, renders the site, runs accessibility and link checks |
| `scripts/check-a11y.R` | Scans rendered pages for accessibility issues (missing alt text, skipped headings, etc.) |
| `scripts/check-links.R` | Scans rendered pages for broken local links and images |
| `scripts/check-pdf.R` | Checks a PDF file: page count and text extraction from first 3 pages |
| `scripts/clean-site-libs.R` | Post-render cleanup: removes source maps, reactable doc files, and adds alt text to listing thumbnails |
| `scripts/process-newsletters.R` | Processes Gmail-saved newsletter HTMLs into QMD pages + cleaned HTML + PDFs |
| `scripts/extract_newsletter.R` | Helper for `process-newsletters.R`: extracts newsletter body and leading photo from Gmail HTML |
| `scripts/html_to_pdf.R` | Helper for `process-newsletters.R`: converts cleaned HTML to PDF via headless Chrome |
| `scripts/optimize-media.sh` | Bulk compression for images and PDFs in a directory |

---

## Styling rules

The site's look is controlled in three places, in order of preference:

1. **`_brand.yml`**: colors and fonts, with separate light/dark values. *Always change colors here.*
2. **`theme.scss`**: custom rules built on the brand variables.
3. **`_partials/*.scss`**: per-component styling (navbar, cards, tables, …), imported by `theme.scss`.

Rules that keep the design consistent:

- **Never hardcode hex colors in a `.qmd` file or inline style.** Hardcoded values ignore dark mode. Use the existing CSS classes instead.
- **Don't re-declare brand variables in `theme.scss`**; the top of that file lists which variables `_brand.yml` owns.
- Test styling changes in both light and dark mode (toggle in the navbar) before you hand off your changes.

---

## Accessibility checks

The site has a built-in checker that scans every rendered page for problems that affect screen readers and other assistive technology: images without alt text, links without readable names, skipped heading levels, unnamed embedded frames, and tables without header cells.

Run it after a full render:

```bash
Rscript scripts/check-a11y.R          # summary
Rscript scripts/check-a11y.R --full   # every finding, page by page
```

A companion script checks for broken local links and images:

```bash
Rscript scripts/check-links.R
```

It reports a handful of findings in archived e-news email HTML. Those files are historical and safe to ignore.

The summary prints a count per problem type. The site currently passes with zero findings; aim to keep it there after your edits.

Quarto also has a built-in checker powered by axe-core, the industry-standard accessibility engine. It runs in the browser rather than from the command line. To use it, preview the site with the debug profile:

```bash
quarto preview --profile debug
```

Each page then shows an accessibility report at the bottom, with findings labeled by WCAG level. The checker loads from a CDN, so it needs an internet connection. The debug profile is never part of the normal build. When you are done checking, close the preview and run a normal render so `docs/` holds clean pages before you hand anything off.

Three habits prevent most findings:

1. **Every image needs alt text.** For a picture that adds meaning, write a short description. Quarto syntax: `![](images/photo.jpg){fig-alt="Short description"}`. Inside an R chunk, set the `fig.alt` chunk option instead.
2. **Text that just looks like a heading should not be one.** For big bold text that isn't a page section, use a span: `[Your text]{.h5}` (sizes run `.h1` through `.h6`). Reserve `#` through `###` headings for real page structure.
3. **Watch headings inside styled boxes.** When a markdown heading is the very first thing inside a `:::` div, Quarto quietly shifts its level down. If a heading looks right on the page but the checker reports the wrong level, put an empty guard div above it:

   ```
   ::: content-block-blue
   ::: heading-guard
   :::
   ## Your heading
   :::
   ```

One more piece runs on its own: `assets/a11y.html` loads a small script with every page and corrects the heading levels that Quarto generates for listing cards and category sidebars. You never need to touch it.

---

## Troubleshooting

**`renv::restore()` fails or packages won't compile (especially on Apple Silicon Macs)**

```bash
xcode-select --install   # in Terminal
```

```r
options(install.packages.compile.from.source = "never")
renv::repair()     # fixes broken symlinks
renv::restore()
```

**A page renders but shows old content**: the page is frozen. Render it explicitly: `quarto render path/to/page.qmd`.

**The home page lost its e-news cards, or a listing page came out empty**: someone previewed a single page instead of the whole site (see [What not to do](#what-not-to-do)). The source files are fine; only the built output is broken. Run `quarto render` with no arguments (or `Rscript scripts/build-site.R`) to rebuild everything. If the folder is under git, `git checkout -- docs/ _freeze/` first restores the last good build in one step.

**`quarto render` stops with an error**: the error message names the file and usually the line. Common causes are an unclosed `:::` div, a link path that doesn't match the file's location, or a YAML value containing a colon that isn't quoted. Fix it and render again. If you can't spot the problem, restore your backup copy of that file and ask the web editor.

**An update script says a Sheet tab returned 0 rows**: the tab was probably renamed or the Sheet's sharing changed. Fix the tab name / sharing ("anyone with the link can view") and re-run; your existing CSV was left untouched.

**Still stuck?** Email [webeditor@ap-ls.org](mailto:webeditor@ap-ls.org) or [report an issue](https://docs.google.com/forms/d/e/1FAIpQLSfOL2JsE-YbvqH09-S6zcukZ6qiOycK98DjXa08MDygMTWBYA/viewform?usp=sf_link).

---

## For volunteers

- R package versions are pinned with `renv`. After cloning: `renv::restore()`, then `renv::install("./apls-r")` to install the local `aplsr` package.
- `Rscript scripts/build-site.R` renders the whole site and runs the accessibility and link checks in one pass.
- Pages that execute R code are frozen (`freeze: auto` in `_quarto.yml`); Quarto only re-executes pages whose source changed.
- Styling rules: define colors in `_brand.yml`, not in `theme.scss` or inline styles — hardcoded values break dark mode. See the comments at the top of `theme.scss`.
- The `aplsr` package has its own tests (`apls-r/tests/`) and documentation (`apls-r/vignettes/getting-started.qmd`).
