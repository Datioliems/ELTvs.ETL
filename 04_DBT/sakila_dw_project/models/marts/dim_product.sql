{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH inv_count AS (
    SELECT film_id, COUNT(*) AS inventory_count
    FROM {{ source('raw_mysql_inventory', 'inventory') }}
    GROUP BY film_id
),
source AS (
    SELECT
        f.film_id,
        f.title, f.description,
        f.release_year, f.language_id,
        f.rental_duration, f.rental_rate,
        f.replacement_cost, f.rating,
        f.category_name,
        ISNULL(i.inventory_count, 0) AS inventory_count
    FROM {{ ref('stg_inv_film') }} f
    LEFT JOIN inv_count i ON f.film_id = i.film_id
)

{% if is_incremental() %}

, current_dim AS (
    SELECT * FROM {{ this }} WHERE is_current = 1
)

, to_expire AS (
    SELECT d.film_id
    FROM current_dim d
    JOIN source s ON d.film_id = s.film_id
    WHERE CAST(s.rental_rate      AS VARCHAR(20)) <> CAST(d.rental_rate      AS VARCHAR(20))
       OR CAST(s.rental_duration  AS VARCHAR(20)) <> CAST(d.rental_duration  AS VARCHAR(20))
       OR CAST(s.replacement_cost AS VARCHAR(20)) <> CAST(d.replacement_cost AS VARCHAR(20))
       OR ISNULL(s.rating,'')                     <> ISNULL(d.rating,'')
       OR ISNULL(s.category_name,'')              <> ISNULL(d.category_name,'')
)

SELECT
    d.film_id,
    d.title, d.description, d.release_year, d.language_id,
    d.rental_rate, d.rental_duration, d.replacement_cost, d.rating, d.category_name,
    s.inventory_count,
    d.effective_date,
    CAST(GETDATE() AS DATE) AS expiry_date,
    0                       AS is_current
FROM current_dim d
JOIN source s ON d.film_id = s.film_id
WHERE d.film_id IN (SELECT film_id FROM to_expire)

UNION ALL

SELECT
    s.film_id,
    s.title, s.description, s.release_year, s.language_id,
    s.rental_rate, s.rental_duration, s.replacement_cost, s.rating, s.category_name,
    s.inventory_count,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.film_id IN (SELECT film_id FROM to_expire)

UNION ALL

SELECT
    s.film_id,
    s.title, s.description, s.release_year, s.language_id,
    s.rental_rate, s.rental_duration, s.replacement_cost, s.rating, s.category_name,
    s.inventory_count,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.film_id NOT IN (SELECT film_id FROM current_dim)

{% else %}

SELECT
    film_id, title, description, release_year, language_id,
    rental_rate, rental_duration, replacement_cost, rating, category_name,
    inventory_count,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source

{% endif %}