{{
  config(
    materialized = 'incremental',
    unique_key = 'rental_id',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH rental  AS (SELECT * FROM {{ ref('stg_sales_rental') }}),
     payment AS (SELECT * FROM {{ ref('stg_sales_payment') }}),
     inv     AS (SELECT * FROM {{ source('raw_mysql_inventory','inventory') }}),
     film    AS (SELECT * FROM {{ ref('stg_inv_film') }})

SELECT
    r.rental_id,
    r.customer_id,
    f.film_id,
    i.store_id,
    r.staff_id,
    CAST(CONVERT(VARCHAR, r.rental_date,  112) AS INT) AS rental_date_key,
    CAST(CONVERT(VARCHAR, r.return_date,  112) AS INT) AS return_date_key,
    CAST(CONVERT(VARCHAR, p.payment_date, 112) AS INT) AS payment_date_key,
    ISNULL(p.amount, 0)                                AS amount,
    f.rental_duration                                  AS rental_duration_expected,
    DATEDIFF(DAY, r.rental_date, r.return_date)        AS rental_duration_actual,
    CASE
        WHEN r.return_date IS NULL THEN NULL
        WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
        THEN DATEDIFF(DAY, r.rental_date, r.return_date) - f.rental_duration
        ELSE 0
    END                                                AS late_days,
    CASE
        WHEN r.return_date IS NOT NULL
         AND DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
        THEN 1 ELSE 0
    END                                                AS is_late,
    CASE WHEN r.return_date IS NULL THEN 0 ELSE 1 END  AS is_returned,
    f.replacement_cost
FROM rental r
LEFT JOIN payment p   ON r.rental_id    = p.rental_id
LEFT JOIN inv     i   ON r.inventory_id = i.inventory_id
LEFT JOIN film    f   ON i.film_id      = f.film_id

{% if is_incremental() %}
WHERE r.rental_id NOT IN (SELECT rental_id FROM {{ this }})
{% endif %}