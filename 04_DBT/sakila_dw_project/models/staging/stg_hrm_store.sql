WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY _airbyte_extracted_at DESC
        ) AS rn
    FROM {{ source('raw_hrm', 'store') }}
)
SELECT
    CAST(s.store_id         AS INT)          AS store_id,
    CAST(s.manager_staff_id AS INT)          AS manager_staff_id,
    CAST(s.address_id       AS INT)          AS address_id,
    CAST(a.address          AS VARCHAR(100)) AS address,
    CAST(a.district         AS VARCHAR(50))  AS district,
    CAST(ci.city            AS VARCHAR(50))  AS city,
    CAST(co.country         AS VARCHAR(50))  AS country,
    s._airbyte_extracted_at                  AS extracted_at
FROM ranked s
LEFT JOIN {{ source('raw_hrm', 'address') }} a  ON s.address_id  = a.address_id
LEFT JOIN {{ source('raw_hrm', 'city') }}    ci ON a.city_id     = ci.city_id
LEFT JOIN {{ source('raw_hrm', 'country') }} co ON ci.country_id = co.country_id
WHERE s.rn = 1