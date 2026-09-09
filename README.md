# SEEK Marketplace Quality Signals

A small end-to-end analytics engineering project: **dbt (dbt-core + DuckDB) → Tableau**,
built on a real snapshot of SEEK Australia job listings. It's a personal portfolio piece
put together for a SEEK Data Analyst (Candidate Quality) application -- to demonstrate a
dbt + Git-based transformation workflow and a Tableau dashboard, the two tools called out
in that job description that weren't otherwise evidenced on my resume.

**This is an unofficial, personal project.** It is not affiliated with, endorsed by, or
built using any internal SEEK data -- it uses a public, historical dataset of scraped
SEEK job ads. See [Branding & disclaimers](#branding--disclaimers) below.

## The angle: "marketplace quality signals"

The public dataset is scraped job **ads** (title, category, salary text, hirer, dates) --
it has no candidate, application, or matching data, so it can't replicate SEEK's actual
candidate-quality models. Instead this project treats **job-ad quality as a proxy for
marketplace health**, in the spirit of what a Candidate Quality / Product Analytics team
would care about:

- **Salary transparency** -- what share of ads disclose a salary, and does it vary by category?
- **Duplicate / repost detection** -- how much of the volume is exact reposts?
- **Hirer concentration** -- how much volume sits with a handful of high-volume advertisers
  (mostly recruitment agencies and job aggregators) vs. direct employers?
- **Listing trends over time** -- do these signals drift week to week?

## Dataset

[PromptCloud's "Latest Seek Australia Job Dataset"](https://www.kaggle.com/datasets/promptcloud/latest-seek-australia-job-dataset)
on Kaggle: ~10,000 scraped `seek.com.au` job ads, posted **8 Aug – 31 Oct 2019**. It's a
static historical snapshot, not live data -- treat every metric here as "what this
snapshot looked like," not "what SEEK looks like today."

The raw file isn't committed to this repo (see `.gitignore`) -- third-party scraped data,
unclear redistribution terms. To rebuild from scratch:
1. Download the dataset from the Kaggle link above (needs a Kaggle account)
2. Unzip it and place the `.json` file at `data/raw/seek_job_listings.jsonl` (it's
   newline-delimited JSON despite the `.json` extension from Kaggle)

## Architecture

```
data/raw/seek_job_listings.jsonl   (not committed -- see above)
        |
        |  dbt-duckdb reads the JSON lines file directly as an external source
        v
stg_seek_job_listings               staging: 1:1 cleaning/typing, no business logic
        |
        v
int_job_listings_enriched           intermediate: salary parsing, salary-transparency
        |                            flag, duplicate-ad detection, description length
        v
mart_overview_kpis                  4 marts, aggregated for the dashboard:
mart_category_quality_signals         - headline KPI row
mart_hirer_concentration              - per-category quality signals
mart_listing_quality_trend            - per-hirer concentration (Pareto)
                                       - weekly trend
        |
        v
tableau/exports/*.csv               exported for Tableau to read
```

Layer conventions: **staging** renames/types columns and does light null-handling, one
model per source, materialized as views. **Intermediate** carries the derived business
logic (salary parsing, flags) so the marts stay simple aggregations. **Marts** are one
row per dashboard grain, materialized as tables.

## Running it

```bash
cd dbt
pip install dbt-core dbt-duckdb   # or use a venv
dbt build --profiles-dir .        # runs all models + all tests
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .   # browsable docs + lineage graph
```

This builds `data/seek_marketplace_quality.duckdb` (gitignored -- it's a build artifact,
rebuild it any time from the raw file). 26 checks run on `dbt build` (6 models, 20 tests):
uniqueness/not-null on every grain, an `accepted_values` check on `job_type`, and a
singular test (`tests/assert_salary_estimate_reasonable.sql`) that catches salary-parsing
bugs by asserting every parsed estimate falls in a plausible AUD range.

To refresh the CSVs Tableau reads, after `dbt build`:
```bash
python3 -c "
import duckdb
con = duckdb.connect('data/seek_marketplace_quality.duckdb', read_only=True)
for t in ['mart_overview_kpis','mart_category_quality_signals','mart_hirer_concentration','mart_listing_quality_trend']:
    con.execute(f\"COPY (select * from main_marts.{t}) TO 'tableau/exports/{t}.csv' (HEADER, DELIMITER ',')\")
"
```
(run from the `dbt/` directory, so the relative source path in `_staging__sources.yml` resolves)

## Known limitations

- **`days_to_expiry` was dropped.** The plan was a rough "how long ads stay live" proxy
  from `has_expired` / `last_expiry_check_date`, but `has_expired` is `false` or missing
  for all 10,000 rows in this snapshot -- no ad in the crawl window was ever caught expiring.
  Caught by profiling before it reached a mart; not derivable from this dataset.
- **Salary parsing is best-effort regex, not NLP.** It correctly handles the two dominant
  formats ("$X - $Y per hour" and "$X,XXX - $Y,YYY") but ~0.5% of disclosed-salary ads use
  compound free text (e.g. `"(OTE$200k+) uncapped comm + super"`) that doesn't fit a single
  pattern. Those are nulled out and flagged via `salary_estimate_suspect` rather than
  publishing a garbled number -- see the comment in `int_job_listings_enriched.sql`.
- **Duplicate detection is a heuristic** (exact match on title + hirer + city), not a
  content-similarity model -- it catches exact reposts, not near-duplicates, and can
  mis-group ads with a missing city.
- **`company_name` is the advertiser, not necessarily the employer** -- a large share of
  volume (see `mart_hirer_concentration`) is recruitment agencies and the "Jora Local" /
  "Private Advertiser" aggregator buckets, not direct employers.

## Branding & disclaimers

The Tableau dashboard is styled with SEEK's public brand colours for visual consistency
with a real-world case study, and carries a visible "unofficial portfolio project -- not
affiliated with or endorsed by SEEK" label. No internal SEEK systems, data, or
credentials were used anywhere in this project.

## Dashboard

Built in Tableau Public from the four CSVs in `tableau/exports/` -- a KPI row, a
category volume/salary-transparency view, a hirer-concentration Pareto chart, and a
weekly trend view. Published at: **[link to add after publishing]**
