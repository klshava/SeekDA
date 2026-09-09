-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: single-row headline KPI
--   summary for the dashboard's top stat-tile row

-- ============================================================

with base as (

    select * from {{ ref('int_job_listings_enriched') }}

)

select
    count(*)                                                                        as total_postings,
    count(distinct company_name)                                                    as total_unique_hirers,
    count(distinct category)                                                        as total_categories,
    min(post_date)                                                                  as earliest_post_date,
    max(post_date)                                                                  as latest_post_date,
    round(100.0 * sum(case when has_salary_disclosed then 1 else 0 end) / count(*), 1)      as pct_salary_disclosed,
    round(100.0 * sum(case when is_duplicate_ad then 1 else 0 end) / count(*), 1)           as pct_duplicate_ads,
    round(100.0 * sum(case when has_direct_contact_email then 1 else 0 end) / count(*), 1)  as pct_direct_contact_email,
    round(avg(description_word_count), 0)                                          as avg_description_word_count

from base
