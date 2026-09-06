-- =====================================================================
-- אימות: מה יש ב-RAW ומה dbt בנה מזה
-- להרצה ב-worksheet. כל שאילתה עומדת בפני עצמה.
-- =====================================================================

use role transformer;
use warehouse transforming;

-- ---------------------------------------------------------------------
-- 1. שכבת ה-RAW — מה שכבת ה-EL הביאה
-- ---------------------------------------------------------------------
select 'customers' as tbl, count(*) as n from raw.crm.customers
union all select 'policies', count(*) from raw.crm.policies
union all select 'claims',   count(*) from raw.crm.claims
order by 1;

-- ---------------------------------------------------------------------
-- 2. מה dbt בנה, ומאיזה סוג
--    staging חייב להיות VIEW, marts חייב להיות BASE TABLE,
--    ו-int_claims_enriched לא אמור להופיע כאן בכלל (ephemeral)
-- ---------------------------------------------------------------------
select table_schema, table_name, table_type, row_count
from analytics.information_schema.tables
where table_schema in ('DBT_GIL_STAGING', 'DBT_GIL_MARTS')
order by table_schema, table_name;

-- ---------------------------------------------------------------------
-- 3. חותמת dbt_created — צריך לצאת ערך אחד בלבד לכל ההרצה
-- ---------------------------------------------------------------------
with all_stamps as (
    select dbt_created from analytics.dbt_gil_staging.stg_crm__customers
    union all select dbt_created from analytics.dbt_gil_staging.stg_crm__policies
    union all select dbt_created from analytics.dbt_gil_staging.stg_crm__claims
    union all select dbt_created from analytics.dbt_gil_marts.dim_customers
    union all select dbt_created from analytics.dbt_gil_marts.dim_policies
    union all select dbt_created from analytics.dbt_gil_marts.fct_claims
)
select count(*) as total_rows,
       count(distinct dbt_created) as distinct_stamps,   -- אמור להיות 1
       min(dbt_created) as stamp
from all_stamps;

-- ---------------------------------------------------------------------
-- 4. הניקוי שקרה בשכבת ה-stage
--    ב-RAW הסטטוס מגיע 'ACTIVE' / ' active ' / 'Active'
-- ---------------------------------------------------------------------
select r.policy_id,
       '[' || r.status || ']'   as raw_status,
       '[' || s.policy_status || ']' as staged_status,
       s.is_active
from raw.crm.policies r
join analytics.dbt_gil_staging.stg_crm__policies s using (policy_id)
order by r.policy_id;

-- ---------------------------------------------------------------------
-- 5. שאילתה עסקית אמיתית — עובדות מול מימדים
-- ---------------------------------------------------------------------
select c.full_name,
       c.city,
       c.active_policies_count,
       count(f.claim_id)                       as claims_count,
       sum(f.claim_amount)                     as total_claimed,
       sum(f.paid_amount)                      as total_paid,
       round(sum(f.paid_amount) / nullif(sum(f.claim_amount), 0) * 100, 1) as payout_pct
from analytics.dbt_gil_marts.dim_customers c
left join analytics.dbt_gil_marts.fct_claims f on f.customer_id = c.customer_id
group by 1, 2, 3
order by total_claimed desc nulls last;

-- ---------------------------------------------------------------------
-- 6. הדגל שתופס בעיית איכות נתונים —
--    תביעה שהוגשה מחוץ לתקופת התוקף של הפוליסה
-- ---------------------------------------------------------------------
select f.claim_id, f.claim_number, f.claim_date,
       p.policy_number, p.policy_start_date, p.policy_end_date, p.policy_status
from analytics.dbt_gil_marts.fct_claims f
join analytics.dbt_gil_marts.dim_policies p using (policy_id)
where not f.is_within_policy_period;
