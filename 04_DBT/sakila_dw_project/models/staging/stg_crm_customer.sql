WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY _airbyte_extracted_at DESC
        ) AS rn
    FROM {{ source('raw_crm', 'customer') }}
)
SELECT
    CAST(customer_id AS INT)          AS customer_id,
    CAST(first_name  AS VARCHAR(50))  AS first_name,
    CAST(last_name   AS VARCHAR(50))  AS last_name,
    CAST(email       AS VARCHAR(100)) AS email,
    CAST(address_id  AS INT)          AS address_id,
    CAST(active      AS TINYINT)      AS active,
    CAST(store_id    AS INT)          AS store_id,
    _airbyte_extracted_at             AS extracted_at
FROM ranked
WHERE rn = 1