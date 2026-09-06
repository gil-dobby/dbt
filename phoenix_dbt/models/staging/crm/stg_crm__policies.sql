with source as (

    select * from {{ source('crm', 'policies') }}

),

renamed as (

    select
        -- מפתחות
        policy_id,
        customer_id,
        policy_number,

        -- מאפיינים
        product_code,
        lower(trim(status))                             as policy_status,
        upper(coalesce(currency, 'ILS'))                as currency,

        -- מדדים
        cast(premium_amount as number(18,2))            as premium_amount,

        -- תאריכים
        cast(start_date as date)                        as policy_start_date,
        cast(end_date   as date)                        as policy_end_date,

        -- דגלים
        lower(trim(status)) = 'active'                  as is_active,

        -- מטא-דאטה של המקור
        cast(created_at as timestamp_ntz)               as source_created_at,
        cast(updated_at as timestamp_ntz)               as source_updated_at,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from source

)

select * from renamed
