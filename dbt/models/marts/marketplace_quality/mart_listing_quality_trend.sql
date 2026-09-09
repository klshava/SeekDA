-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: weekly trend of posting
--   volume and quality signals across the snapshot window

-- ============================================================

with base as (

    select * from {{ ref('int_job_listings_enriched') }}
    where post_date is not null

)

select
    date_trunc('week', post_date)::date                                                 as week_start,
    count(*)                                                                             as postings_count,
    round(100.0 * sum(case when has_salary_disclosed then 1 else 0 end) / count(*), 1)      as pct_salary_disclosed,
    round(100.0 * sum(case when is_duplicate_ad then 1 else 0 end) / count(*), 1)           as pct_duplicate_ads,
    round(avg(description_word_count), 0)                                               as avg_description_word_count

from base
group by 1
order by 1
