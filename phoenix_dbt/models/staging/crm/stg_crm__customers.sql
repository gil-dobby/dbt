with source as (

    select * from {{ source('crm', 'customers') }}

),

renamed as (

    select
        -- מפתחות
        customer_id,
        id_number                                       as national_id,

        -- מאפיינים
        first_name,
        last_name,
        trim(first_name || ' ' || last_name)            as full_name,
        lower(trim(email))                              as email,
        phone,
        city,

        -- תאריכים
        cast(birth_date as date)                        as birth_date,
        cast(created_at as timestamp_ntz)               as source_created_at,
        cast(updated_at as timestamp_ntz)               as source_updated_at,

        -- מטא-דאטה של dbt
        {{ dbt_created() }}                             as dbt_created

    from source

)

select * from renamed
