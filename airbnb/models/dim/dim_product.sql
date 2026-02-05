select
    Product_ID
    ,Product_NK
    ,Product_name
    ,Category
    ,Brand
    ,Base_Price
    ,Is_Active
from
    {{ ref('src_product') }}