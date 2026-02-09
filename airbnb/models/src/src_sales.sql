select
    *
from
    {{ source('airbnb', 'sales') }}