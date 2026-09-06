with policies as (

    select * from {{ ref('stg_crm__policies') }}

),

customers as (

    select * from {{ ref('stg_crm__customers') }}

),

final as (

    select
        -- מפתחות
        policies.policy_id,
        policies.policy_number,
        policies.customer_id,

        -- מאפיינים מהפוליסה
        policies.product_code,
        policies.policy_status,
        policies.currency,

        -- מאפיינים מהלקוח (denormalized לנוחות ה-BI)
        customers.full_name                             as customer_name,
        customers.city                                  as customer_city,

        -- מדדים
        policies.premium_amount,

        -- תאריכים
        policies.policy_start_date,
        policies.policy_end_date,
        datediff('day', policies.policy_start_date, policies.policy_end_date)
                                                        as policy_duration_days,

        -- דגלים
        policies.is_active,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from policies
    left join customers
        on policies.customer_id = customers.customer_id

)

select * from final
