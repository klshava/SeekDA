-- ============================================================
------------------------Change Tracking------------------------

-- 01/01/2022 - BI Team - Initial development
-- 09/09/2026 - Kudzai Shava - Initial development: light cleaning/typing of raw
--   scraped SEEK job listings (1:1 with source, no business logic here)

-- ============================================================

with source as (

    select * from {{ source('raw', 'seek_job_listings') }}

),

renamed as (

    select
        uniq_id                                                                  as listing_id,
        url                                                                      as listing_url,
        nullif(trim(job_title), '')                                              as job_title,
        nullif(trim(category), '')                                               as category,
        nullif(trim(company_name), '')                                           as company_name,

        -- prefer PromptCloud's inferred location fields (more complete than the
        -- raw scraped ones per source profiling), fall back to the raw fields
        coalesce(nullif(trim(inferred_city), ''), nullif(trim(city), ''))        as city,
        coalesce(nullif(trim(inferred_state), ''), nullif(trim(state), ''))      as state,
        coalesce(nullif(trim(inferred_country), ''), nullif(trim(country), ''))  as country,

        try_cast(post_date as date)                                              as post_date,
        job_description,
        nullif(trim(job_type), '')                                               as job_type,
        nullif(trim(salary_offered), '')                                         as salary_offered_raw,
        nullif(trim(contact_email), '')                                          as contact_email,

        -- has_expired arrives as a mix of boolean and string 'true'/'false' in the
        -- source JSON depending on the row; normalise via a text comparison so both
        -- shapes resolve the same way
        case
            when lower(trim(cast(has_expired as varchar))) = 'true' then true
            when lower(trim(cast(has_expired as varchar))) = 'false' then false
            else null
        end                                                                      as has_expired,

        try_strptime(last_expiry_check_date, '%Y.%m.%d')::date                   as last_expiry_check_date,
        try_cast(fitness_score as integer)                                       as source_fitness_score,
        cast(crawl_timestamp as varchar)                                         as crawl_timestamp_raw

    from source

)

select * from renamed
