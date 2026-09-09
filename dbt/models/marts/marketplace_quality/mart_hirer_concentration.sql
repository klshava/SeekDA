-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: per-hirer (advertiser)
--   rollup to show marketplace concentration -- how much volume sits with
--   the top few recruitment agencies/employers

-- ============================================================

with base as (

    select * from {{ ref('int_job_listings_enriched') }}
    where company_name is not null

),

agg as (

    select
        company_name,
        count(*)                                                                          as postings_count,
        count(distinct category)                                                         as categories_spanned,
        count(distinct city)                                                             as cities_spanned,
        round(100.0 * sum(case when has_salary_disclosed then 1 else 0 end) / count(*), 1)  as pct_salary_disclosed,
        round(100.0 * sum(case when is_duplicate_ad then 1 else 0 end) / count(*), 1)       as pct_duplicate_ads
    from base
    group by 1

),

totals as (

    select sum(postings_count) as grand_total from agg

)

select
    agg.*,
    round(100.0 * agg.postings_count / totals.grand_total, 2)                            as pct_of_total_postings,
    row_number() over (order by agg.postings_count desc)                                 as volume_rank

from agg
cross join totals
order by postings_count desc
