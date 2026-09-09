-- Singular test (no external packages needed, network egress on this box is
-- restricted): fails if any parsed salary estimate falls outside a sane
-- $0-$1,000,000 AUD annual range, which would indicate a parsing bug.
select *
from {{ ref('int_job_listings_enriched') }}
where salary_est_annual_aud is not null
  and (salary_est_annual_aud < 0 or salary_est_annual_aud > 1000000)
