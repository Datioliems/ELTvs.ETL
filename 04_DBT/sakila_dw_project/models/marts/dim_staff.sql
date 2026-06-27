{{
  config(
    materialized = 'incremental',
    unique_key = 'staff_id',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH source AS (
    SELECT
        s.staff_id,
        s.first_name, s.last_name, s.username,
        s.email,
        s.store_id, s.address_id,
        a.address, a.district,
        ci.city, co.country
    FROM {{ ref('stg_hrm_staff') }} s
    LEFT JOIN {{ source('raw_hrm','address') }}  a  ON s.address_id  = a.address_id
    LEFT JOIN {{ source('raw_hrm','city') }}     ci ON a.city_id     = ci.city_id
    LEFT JOIN {{ source('raw_hrm','country') }}  co ON ci.country_id = co.country_id
)

{% if is_incremental() %}

, current_dim AS (
    SELECT * FROM {{ this }} WHERE is_current = 1
)

, to_expire AS (
    SELECT d.staff_id
    FROM current_dim d
    JOIN source s ON d.staff_id = s.staff_id
    WHERE ISNULL(CAST(s.store_id AS VARCHAR(20)),'') <> ISNULL(CAST(d.store_id AS VARCHAR(20)),'')
       OR ISNULL(s.address,'')                       <> ISNULL(d.address,'')
       OR ISNULL(s.city,'')                          <> ISNULL(d.city,'')
       OR ISNULL(s.country,'')                       <> ISNULL(d.country,'')
       OR ISNULL(s.district,'')                      <> ISNULL(d.district,'')
)

SELECT
    d.staff_id,
    d.first_name, d.last_name, d.username,
    s.email,
    d.store_id, d.address_id,
    d.address, d.district, d.city, d.country,
    d.effective_date,
    CAST(GETDATE() AS DATE) AS expiry_date,
    0                       AS is_current
FROM current_dim d
JOIN source s ON d.staff_id = s.staff_id
WHERE d.staff_id IN (SELECT staff_id FROM to_expire)

UNION ALL

SELECT
    s.staff_id,
    s.first_name, s.last_name, s.username, s.email,
    s.store_id, s.address_id,
    s.address, s.district, s.city, s.country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.staff_id IN (SELECT staff_id FROM to_expire)

UNION ALL

SELECT
    s.staff_id,
    s.first_name, s.last_name, s.username, s.email,
    s.store_id, s.address_id,
    s.address, s.district, s.city, s.country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.staff_id NOT IN (SELECT staff_id FROM current_dim)

{% else %}

SELECT
    staff_id,
    first_name, last_name, username, email,
    store_id, address_id,
    address, district, city, country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source

{% endif %}