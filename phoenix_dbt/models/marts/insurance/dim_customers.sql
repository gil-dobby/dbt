with customers as (

    select * from {{ ref('stg_crm__customers') }}

),

policies as (

    select * from {{ ref('stg_crm__policies') }}

),

policy_stats as (

    select
        customer_id,
        count(*)                                        as policies_count,
        count_if(is_active)                             as active_policies_count,
        sum(premium_amount)                             as total_premium_amount,
        min(policy_start_date)                          as first_policy_start_date
    from policies
    group by 1

),

final as (

    select
        -- מפתחות
        customers.customer_id,
        customers.national_id,

        -- מאפיינים
        customers.full_name,
        customers.first_name,
        customers.last_name,
        customers.email,
        customers.phone,
        customers.city,
        customers.birth_date,
        datediff('year', customers.birth_date, current_date())  as age,

        -- מדדים מצטברים
        coalesce(policy_stats.policies_count, 0)                as policies_count,
        coalesce(policy_stats.active_policies_count, 0)         as active_policies_count,
        coalesce(policy_stats.total_premium_amount, 0)          as total_premium_amount,
        policy_stats.first_policy_start_date,

        -- דגלים
        coalesce(policy_stats.active_policies_count, 0) > 0     as is_active_customer,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                                     as dbt_created

    from customers
    left join policy_stats
        on customers.customer_id = policy_stats.customer_id

)

select * from final
