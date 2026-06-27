{{
  config(
    materialized = 'incremental',
    unique_key = 'customer_id',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH source AS (
    SELECT
        c.customer_id,
        c.first_name, c.last_name,
        c.email,
        c.address_id, c.active, c.store_id,
        a.address, a.district,
        ci.city, co.country
    FROM {{ ref('stg_crm_customer') }} c
    LEFT JOIN {{ source('raw_crm','address') }}  a  ON c.address_id  = a.address_id
    LEFT JOIN {{ source('raw_crm','city') }}     ci ON a.city_id     = ci.city_id
    LEFT JOIN {{ source('raw_crm','country') }}  co ON ci.country_id = co.country_id
)

{% if is_incremental() %}

, current_dim AS (
    SELECT * FROM {{ this }} WHERE is_current = 1
)

, to_expire AS (
    SELECT d.customer_id
    FROM current_dim d
    JOIN source s ON d.customer_id = s.customer_id
    WHERE ISNULL(CAST(s.address_id AS VARCHAR(20)),'') <> ISNULL(CAST(d.address_id AS VARCHAR(20)),'')
       OR ISNULL(CAST(s.active     AS VARCHAR(20)),'') <> ISNULL(CAST(d.active     AS VARCHAR(20)),'')
       OR ISNULL(CAST(s.store_id   AS VARCHAR(20)),'') <> ISNULL(CAST(d.store_id   AS VARCHAR(20)),'')
       OR ISNULL(s.city,   '')                         <> ISNULL(d.city,   '')
       OR ISNULL(s.country,'')                         <> ISNULL(d.country,'')
)

-- Bản cũ đóng lại
SELECT
    d.customer_id,
    d.first_name, d.last_name,
    s.email,
    d.address_id, d.active, d.store_id,
    d.address, d.district, d.city, d.country,
    d.customer_class,
    d.effective_date,
    CAST(GETDATE() AS DATE) AS expiry_date,
    0                       AS is_current
FROM current_dim d
JOIN source s ON d.customer_id = s.customer_id
WHERE d.customer_id IN (SELECT customer_id FROM to_expire)

UNION ALL

-- Bản mới thay thế
SELECT
    s.customer_id,
    s.first_name, s.last_name, s.email,
    s.address_id, s.active, s.store_id,
    s.address, s.district, s.city, s.country,
    NULL                    AS customer_class,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.customer_id IN (SELECT customer_id FROM to_expire)

UNION ALL

-- Khách hàng mới
SELECT
    s.customer_id,
    s.first_name, s.last_name, s.email,
    s.address_id, s.active, s.store_id,
    s.address, s.district, s.city, s.country,
    NULL                    AS customer_class,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.customer_id NOT IN (SELECT customer_id FROM current_dim)

{% else %}

SELECT
    customer_id,
    first_name, last_name, email,
    address_id, active, store_id,
    address, district, city, country,
    NULL                    AS customer_class,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source

{% endif %}