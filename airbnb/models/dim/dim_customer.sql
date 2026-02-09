{{
    config(
        materialized = 'view'
    )
}}
select
    Customer_ID
    ,Customer_NK
    ,First_Name
    ,Last_Name
    ,CONCAT(First_Name, ' ', Last_Name) AS Full_Name
    ,Email
    ,State
    ,Segment
from
    {{ ref('src_customer') }}