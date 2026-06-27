WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY film_id
            ORDER BY _airbyte_extracted_at DESC
        ) AS rn
    FROM {{ source('raw_mysql_inventory', 'film') }}
)
SELECT
    CAST(f.film_id          AS INT)           AS film_id,
    CAST(f.title            AS VARCHAR(255))  AS title,
    CAST(f.description      AS VARCHAR(1000)) AS description,
    CAST(f.release_year     AS INT)           AS release_year,
    CAST(f.language_id      AS INT)           AS language_id,
    CAST(f.rental_duration  AS TINYINT)       AS rental_duration,
    CAST(f.rental_rate      AS DECIMAL(4,2))  AS rental_rate,
    CAST(f.replacement_cost AS DECIMAL(5,2))  AS replacement_cost,
    CAST(f.rating           AS VARCHAR(10))   AS rating,
    CAST(c.name             AS VARCHAR(50))   AS category_name,
    f._airbyte_extracted_at                   AS extracted_at
FROM ranked f
LEFT JOIN {{ source('raw_mysql_inventory', 'film_category') }} fc
    ON f.film_id = fc.film_id
LEFT JOIN {{ source('raw_mysql_inventory', 'category') }} c
    ON fc.category_id = c.category_id
WHERE f.rn = 1