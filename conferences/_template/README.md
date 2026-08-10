# Conference page template

This folder is the starting point for each year's conference pages. It is
never published: the leading underscore in `_template` keeps it out of the
rendered site.

## What is in here

```
_template/
  index.qmd                  Main conference page
  index.css                  Conference styles (copy of conferences/index.css)
  images/                    Logo and hotel photo go here
  data/                      Seed CSVs the pages read (see below)
  cfp/index.qmd              Call for proposals sub-page
  preconference/
    index.qmd                Workshops listing and pricing
    workshop_1/index.qmd     Example workshop page (for hand-built pages)
    _metadata.yml            Settings for the workshop pages
    title-block.html         Layout for the workshop pages
  README.md                  This file
```

## How the pages get their content

Two systems, each with its own job:

- **Yearly facts** (year, city, dates, hotel name and address) are set once
  at rollover by finding and replacing placeholders in the copied files.
- **Through-the-year facts** (announcement notes, deadlines, booking and
  registration links, rates, and the workshop list) come from the
  conference Google Sheet. `conferences/_update-conference.R` pulls the
  Sheet into `conferences/data/*.csv` and builds the workshop pages. The
  conference pages read those CSVs when they render, so the site build
  never depends on Google being reachable.

The Sheet's tabs and columns are documented in the header comments of
`conferences/_update-conference.R`. The web editor creates the Sheet once
("anyone with the link can view") and pastes its ID into the script; after
that, co-chairs only edit the Sheet.

## Starting a new conference year

1. Archive the year that ended: move `conferences/index.qmd`, `index.css`,
   `images/`, `data/`, `cfp/`, and `preconference/` into
   `conferences/archive/` under that year. In the archived `index.qmd`,
   change the two links that point at `archive/index.qmd` (the Archives
   tile and the Learn More button) to `../index.qmd`, and update the
   Conferences menu label in `_quarto.yml` to the new year.
2. Copy everything in `_template/` up into `conferences/`. Copy, do not
   move, so the template stays clean for next year.
3. Find and replace each placeholder. The list is in the comment at the
   top of `index.qmd` (`20XX`, `CITY, ST`, `HOTEL NAME`, and so on). The
   same placeholders appear in the seed CSVs in `data/`.
4. Add the conference logo as `images/logo.png` and a hotel photo as
   `images/hotel.png`.
5. Hand the Google Sheet to the new co-chairs (or create next year's copy)
   and update the seed CSVs from it:
   `source("conferences/_update-conference.R")`.
6. Render the conference pages and check them before publishing.

## Updating during the year

Most updates are three steps:

1. Edit the conference Google Sheet.
2. Run `source("conferences/_update-conference.R")` from the project root.
3. Render the conference pages and hand off as usual.

What to change at each stage:

| Stage | When | Sheet changes |
| ----- | ---- | ------------- |
| 2 | Call for proposals opens | `info` tab: `submissions_note`, `cfp_note`, `cfp_deadline`, `submission_portal_url`, `reviewer_form_url`. Then open `cfp/index.qmd` and follow the STAGE 2 comment to make the full call visible. |
| 3 | Room block opens | `info` tab: `hotel_note`, `hotel_booking_url`. The booking callout appears on its own. |
| 4 | Schedule released | `info` tab: `schedule_note`. |
| 5 | Registration opens | `info` tab: `registration_note`, `registration_url` (a Register button appears on its own); `registration-rates` tab for final prices; `workshop-rates` tab for workshop prices. |

Workshops: add one row per workshop to the `workshops` tab and re-run the
script. Each row becomes a page in `preconference/`, and the listing grid
fills in automatically. Set `sort-ui` and `filter-ui` to `true` in
`preconference/index.qmd` once the first workshop is up.

## Rendering

From the project root:

```
quarto render conferences/index.qmd
quarto render conferences/cfp/index.qmd
quarto render conferences/preconference
```

or render the whole site with `quarto render`. Details are in
`UPDATING.md` at the project root, and a co-chair walkthrough is in
`conference-guide/`.
