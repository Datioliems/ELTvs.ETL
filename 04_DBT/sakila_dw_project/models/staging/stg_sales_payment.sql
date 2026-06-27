SELECT
    CAST(payment_id   AS INT)          AS payment_id,
    CAST(rental_id    AS INT)          AS rental_id,
    CAST(customer_id  AS INT)          AS customer_id,
    CAST(staff_id     AS INT)          AS staff_id,
    CAST(amount       AS DECIMAL(5,2)) AS amount,
    CAST(payment_date AS DATETIME)     AS payment_date,
    _airbyte_extracted_at              AS extracted_at
FROM {{ source('raw_sales', 'payment') }}