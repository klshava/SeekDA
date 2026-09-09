-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: per-category volume and
--   quality-signal rollup (salary transparency, duplicate rate, description
--   depth, time-to-expiry) for the category comparison views

-- ============================================================

with base as (

    select * from {{ ref('int_job_listings_enriched') }}
    where category is not null

),

agg as (

    select
        category,
        count(*)                                                                         as postings_count,
        count(distinct company_name)                                                     as distinct_hirers,
        round(100.0 * sum(case when has_salary_disclosed then 1 else 0 end) / count(*), 1)  as pct_salary_disclosed,
        round(avg(salary_est_annual_aud), 0)                                             as avg_est_annual_salary_aud,
        round(100.0 * sum(case when is_duplicate_ad then 1 else 0 end) / count(*), 1)       as pct_duplicate_ads,
        round(avg(description_word_count), 0)                                            as avg_description_word_count
    from base
    group by 1

),

totals as (

    select sum(postings_count) as grand_total from agg

)

select
    agg.*,
    round(100.0 * agg.postings_count / totals.grand_total, 1)                            as pct_of_total_postings

from agg
cross join totals
order by postings_count desc
