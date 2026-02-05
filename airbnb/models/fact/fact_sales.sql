{{
    config(
        materialized = 'incremental'
        ,on_schema_change = 'fail'
    )
}}
SELECT
    *,
    now() AS fact_created_at
FROM
    {{ ref('src_sales') }}
WHERE 1 = 1
{% if is_incremental() %}
    AND {{ ref('src_sales') }}.created_at > (SELECT MAX(created_at) FROM {{ this }})
{% endif %}