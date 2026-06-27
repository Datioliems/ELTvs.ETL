SELECT
    CAST(rental_id    AS INT)      AS rental_id,
    CAST(customer_id  AS INT)      AS customer_id,
    CAST(inventory_id AS INT)      AS inventory_id,
    CAST(staff_id     AS INT)      AS staff_id,
    CAST(rental_date  AS DATETIME) AS rental_date,
    CAST(return_date  AS DATETIME) AS return_date,
    _airbyte_extracted_at          AS extracted_at
FROM {{ source('raw_sales', 'rental') }}