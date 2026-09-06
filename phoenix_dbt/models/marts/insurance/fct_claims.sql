with claims as (

    select * from {{ ref('int_claims_enriched') }}

),

final as (

    select
        -- מפתח ראשי — גרעין: תביעה אחת לשורה
        claim_id,

        -- מפתחות זרים למימדים
        policy_id,
        customer_id,

        -- מזהים עסקיים
        claim_number,
        policy_number,

        -- מאפיינים
        claim_status,
        product_code,
        currency,

        -- מדדים
        claim_amount,
        paid_amount,
        outstanding_amount,
        premium_amount,

        -- תאריכים
        claim_date,
        days_from_policy_start,

        -- דגלים
        is_settled,
        is_within_policy_period,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from claims

)

select * from final
