SELECT
    customer_id
    ,customer_nk
    ,first_name
    ,last_name
    ,email
    ,state
    ,segment
FROM
    {{ source('airbnb', 'customer') }}