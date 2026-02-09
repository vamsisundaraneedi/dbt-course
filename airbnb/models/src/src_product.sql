SELECT
    product_id
    ,product_nk
    ,product_name
    ,category
    ,brand
    ,base_price
    ,is_active
FROM
    {{ source('airbnb', 'product') }}