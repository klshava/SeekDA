-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: salary parsing, salary
--   transparency flag, duplicate-ad detection, description length, and
--   time-to-expiry proxy (the derived "marketplace quality signal" fields)
-- 09/09/2026 - Kudzai Shava - Cap salary_est_annual_aud at a plausible AUD
--   range and flag garbled compound salary strings via salary_estimate_suspect
--   instead of publishing bad numbers (found via assert_salary_estimate_reasonable)

-- ============================================================

with stg as (

    select * from {{ ref('stg_seek_job_listings') }}

),

salary_parsed as (

    select
        *,
        salary_offered_raw is not null                                         as has_salary_disclosed,
        (salary_offered_raw ilike '%per hour%' or salary_offered_raw ilike '%/hr%')
                                                                                 as is_hourly_rate,
        regexp_matches(salary_offered_raw, '\$[0-9]+(\.[0-9]{1,2})?\s*[Kk]')
                                                                                 as is_k_shorthand,

        -- first number in the salary string, e.g. the "45000" in "$45,000 - $49,999"
        try_cast(
            regexp_replace(
                regexp_extract(salary_offered_raw, '\$?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)', 1),
                ',', '', 'g'
            ) as double
        )                                                                       as salary_num_1,

        -- second number, if the string is a range ("... - $49,999")
        try_cast(
            regexp_replace(
                regexp_extract(salary_offered_raw, '-\s*\$?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)', 1),
                ',', '', 'g'
            ) as double
        )                                                                       as salary_num_2

    from stg

),

-- assumptions:
--  * hourly rates are annualised on a 38hr/week, 52-week year
--  * "$NNNk" shorthand is treated as thousands
--  * a range is summarised as its midpoint
-- these break down on a small number of ads with compound free-text salary
-- strings (e.g. mixed-precision ranges like "$70000.00 - $80k p.a.", or
-- "(OTE$200k+) uncapped comm + super") that don't cleanly fit one pattern.
raw_estimate as (

    select
        *,
        case
            when salary_num_1 is null then null
            when is_k_shorthand    then coalesce((salary_num_1 + salary_num_2) / 2, salary_num_1) * 1000
            when is_hourly_rate    then coalesce((salary_num_1 + salary_num_2) / 2, salary_num_1) * 38 * 52
            else                        coalesce((salary_num_1 + salary_num_2) / 2, salary_num_1)
        end                                                                     as salary_est_annual_aud_raw

    from salary_parsed

),

-- rather than publish a garbled number for the handful of compound strings
-- above, anything outside a plausible AUD annual salary range is nulled out
-- and flagged via salary_estimate_suspect for transparency
salary_estimated as (

    select
        * exclude (salary_est_annual_aud_raw),
        case
            when salary_est_annual_aud_raw between 0 and 350000 then salary_est_annual_aud_raw
        end                                                                     as salary_est_annual_aud,
        salary_est_annual_aud_raw is not null
            and salary_est_annual_aud_raw not between 0 and 350000              as salary_estimate_suspect

    from raw_estimate

),

flags as (

    select
        *,
        contact_email is not null                                              as has_direct_contact_email,

        case
            when job_description is null or trim(job_description) = '' then 0
            else len(str_split(trim(job_description), ' '))
        end                                                                     as description_word_count,

        -- NB: days_to_expiry was dropped -- has_expired is never actually
        -- true in this snapshot (checked: 0/10000 rows), so a time-to-expiry
        -- proxy isn't derivable from this dataset. See README known limitations.

        -- heuristic duplicate/repost detection: exact match on title + hirer + city.
        -- rows with a missing city can under/over-count -- see schema.yml note.
        count(*) over (
            partition by job_title, company_name, coalesce(city, '(unknown)')
        )                                                                       as dup_group_size

    from salary_estimated

)

select
    * exclude (salary_num_1, salary_num_2, is_k_shorthand),
    dup_group_size > 1                                                         as is_duplicate_ad

from flags
