# `aplsr` — R Package Plan & Function Manifest

Turning the AP-LS website's shared R functions into an installable package.

- **Package name:** `aplsr` (valid R name; the GitHub repo can be `apls-r`)
- **Repo:** `github.com/<your-org>/apls-r`
- **License:** MIT
- **Scope:** everything reusable (shared file + duplicated inline helpers + standalone scripts)
- **Website consumption:** *unchanged for now* — the site keeps `source("assets/apls_functions.R")`. We build the package in parallel and migrate the site later, so nothing breaks in the meantime.

---

## Part 1 — Function manifest (review this)

Decisions: **export** = public package function; **internal** = package helper, not exported; **consolidate** = one canonical version replaces duplicates; **leave** = stays inline in the `.qmd` (page-specific / anonymous).

### A. Shared file — `assets/apls_functions.R`

| Function | Category | Decision | Notes |
|---|---|---|---|
| `awards_table` | Table builder | export | core; reactable + theme |
| `book_awards_table` | Table builder | export | linked titles |
| `dissertation_table` | Table builder | export | 1st/2nd/3rd columns |
| `apls_table_theme` | Table style | export | shared reactable theme |
| `awards_timeline` | Table/timeline | export (optional) | currently unused; keep as opt-in |
| `carousel`, `carouselItem`, `navButton` | UI/HTML | export `carousel`; others internal | bootstrap carousel |
| `generate_info_bar` | UI/HTML | export | info bar markup |
| `create_inline_object` | UI/HTML | export | inline icon+link |
| `rowwise_table` | Utility | export | from mlr3misc; attribute in docs |

### B. Duplicated inline helpers (consolidate to ONE package function)

| Function | Seen in | Decision |
|---|---|---|
| `with_tooltip` | schedule_tbl.R, syllabi, 2023 & 2024 schedules (4×) | consolidate → export |
| `resource_grid` | index.qmd, resources/index.qmd (2×) | consolidate → export |
| `my_filter_group` | 2023 & 2024 schedules (2×) | consolidate → export |
| `row_details` / `dets_field` / `evnt_field` | committees, schedules, preconference | consolidate to a parameterized `row_details()` → export |

### C. Other inline helpers (move to package)

| Function | Location | Decision |
|---|---|---|
| `obfuscate_email` | committees.qmd | export (text util) |
| `parse_markdown_links` | committees.qmd | export (text util) |
| `cmt_field` | committees.qmd | internal (used by row_details) |
| `pill` | publications/index.qmd | export (badge helper) |

### D. Standalone scripts (refactor into package functions)

| Source | New function | Decision | Heavy deps |
|---|---|---|---|
| `about/_update-ec.R` | `update_ec_data(sheet_id, out_dir)` | export | googlesheets4, yaml |
| `awards/_update-awards.R` | `update_awards_data(sheet_id, out_dir)` | export | googlesheets4 |
| `publications/journal_table.R` | `journal_table(data)` | export | gt |
| `conferences/.../schedule_tbl.R` | `daily_overview()`, uses `with_tooltip` | export | readxl, reactablefmtr, tippy |
| `.../sponsor_logos.R` | `create_sponsor_canvas()` | export | magick, ggimage, ragg |

### E. Leave inline (NOT packaged)

Anonymous `cell = function(...)`, `filterInput = function(...)`, and `rowStyle = function(...)` renderers, and one-off page logic. These are tied to a specific table's columns and aren't reusable.

---

## Part 2 — Dependency strategy

- **Imports (always needed):** `htmltools`, `reactable`, `reactablefmtr`, `dplyr`, `stringr`, `purrr`, `glue`.
- **Suggests (heavy / feature-specific, guarded with `rlang::check_installed()`):** `googlesheets4`, `yaml`, `gt`, `readxl`, `tippy`, `crosstalk`, `magick`, `ggimage`, `ragg`, `here`.
- **Avoid as deps:** `tidyverse` (meta-package), `shiny` (the scan's `shiny` hits are mostly vendored reactable examples under `.quarto/`, not real site code).
- Replace every `library()` call inside functions with `pkg::fun()` / `@importFrom`.

---

## Part 3 — Execution phases (R-package skills)

1. **Scaffold** (`usethis`): `create_package("aplsr")`, MIT license, `use_git()`, `use_testthat()`, README, `use_github_action("check-standard")`.
2. **Generate detailed manifest**: confirm each function's exact deps & call sites (extends Part 1).
3. **Migrate** functions into themed files: `R/tables.R`, `R/html.R`, `R/text-utils.R`, `R/grids.R`, `R/schedule.R`, `R/data-pipeline.R`, `R/sponsors.R` — consolidating duplicates.
4. **Packagify**: remove `library()` side-effects; declare deps; set exports; guard Suggests.
5. **Document** (`roxygen2`): `@param/@return/@export/@examples`; `devtools::document()`.
6. **Test** (`testthat`): real tests for text/data utils; snapshot/smoke tests for table builders.
7. **Check**: `devtools::check()` clean (cran-extrachecks skill).
8. **GitHub**: push to `apls-r`, CI green, optional `pkgdown` site.
9. **(Later, on your go) Wire the site**: swap `source()` → `library(aplsr)`, install via `renv` from GitHub, pin in `renv.lock`, render to verify — incrementally.

---

## Open items / what I need from you

1. Confirm package name **`aplsr`** (or give another) and the **GitHub owner** for `apls-r`.
2. OK to put heavy/optional deps (magick, gt, readxl, googlesheets4, …) in **Suggests** rather than Imports? (Recommended — keeps install light.)
3. Where should the package live on disk while we build it — a **new folder beside** the website repo, or delivered as a zip you place wherever you want the repo?
