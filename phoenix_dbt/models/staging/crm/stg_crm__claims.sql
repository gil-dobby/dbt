with source as (

    select * from {{ source('crm', 'claims') }}

),

renamed as (

    select
        -- מפתחות
        claim_id,
        policy_id,
        claim_number,

        -- מאפיינים
        lower(trim(status))                             as claim_status,
        upper(coalesce(currency, 'ILS'))                as currency,

        -- מדדים
        cast(claim_amount as number(18,2))              as claim_amount,
        cast(paid_amount  as number(18,2))              as paid_amount,

        -- תאריכים
        cast(claim_date as date)                        as claim_date,

        -- דגלים
        lower(trim(status)) in ('paid', 'closed')       as is_settled,

        -- מטא-דאטה של המקור
        cast(created_at as timestamp_ntz)               as source_created_at,
        cast(updated_at as timestamp_ntz)               as source_updated_at,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from source

)

select * from renamed
