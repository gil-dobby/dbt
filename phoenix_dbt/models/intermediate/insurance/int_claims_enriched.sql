{#
    שכבת ביניים: מחברת תביעה לפוליסה וללקוח שלה.
    ephemeral — לא נוצר אובייקט ב-Snowflake, ה-SQL מוטמע ב-fct_claims.
    זו השכבה הראשונה שבה מותרים joins.
#}

with claims as (

    select * from {{ ref('stg_crm__claims') }}

),

policies as (

    select * from {{ ref('stg_crm__policies') }}

),

joined as (

    select
        -- מפתחות
        claims.claim_id,
        claims.policy_id,
        policies.customer_id,
        claims.claim_number,
        policies.policy_number,

        -- מאפיינים
        claims.claim_status,
        policies.product_code,
        policies.policy_status,
        claims.currency,

        -- מדדים
        claims.claim_amount,
        claims.paid_amount,
        claims.claim_amount - claims.paid_amount        as outstanding_amount,
        policies.premium_amount,

        -- תאריכים
        claims.claim_date,
        policies.policy_start_date,
        policies.policy_end_date,
        datediff('day', policies.policy_start_date, claims.claim_date)
                                                        as days_from_policy_start,

        -- דגלים
        claims.is_settled,
        claims.claim_date between policies.policy_start_date
                              and coalesce(policies.policy_end_date, '9999-12-31')
                                                        as is_within_policy_period,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from claims
    left join policies
        on claims.policy_id = policies.policy_id

)

select * from joined
