{{
  config(
    materialized = 'incremental',
    unique_key = 'store_id',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH source AS (
    SELECT
        store_id, manager_staff_id,
        address_id, address, district, city, country
    FROM {{ ref('stg_hrm_store') }}
)

{% if is_incremental() %}

, current_dim AS (
    SELECT * FROM {{ this }} WHERE is_current = 1
)

, to_expire AS (
    SELECT d.store_id
    FROM current_dim d
    JOIN source s ON d.store_id = s.store_id
    WHERE ISNULL(s.address, '')  <> ISNULL(d.address, '')
       OR ISNULL(s.city, '')     <> ISNULL(d.city, '')
       OR ISNULL(s.country, '')  <> ISNULL(d.country, '')
       OR ISNULL(s.district, '') <> ISNULL(d.district, '')
)

SELECT
    d.store_id, d.manager_staff_id,
    d.address_id, d.address, d.district, d.city, d.country,
    d.effective_date,
    CAST(GETDATE() AS DATE) AS expiry_date,
    0                       AS is_current
FROM current_dim d
WHERE d.store_id IN (SELECT store_id FROM to_expire)

UNION ALL

SELECT
    s.store_id, s.manager_staff_id,
    s.address_id, s.address, s.district, s.city, s.country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.store_id IN (SELECT store_id FROM to_expire)

UNION ALL

SELECT
    s.store_id, s.manager_staff_id,
    s.address_id, s.address, s.district, s.city, s.country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source s
WHERE s.store_id NOT IN (SELECT store_id FROM current_dim)

{% else %}

SELECT
    store_id, manager_staff_id,
    address_id, address, district, city, country,
    CAST(GETDATE() AS DATE) AS effective_date,
    NULL                    AS expiry_date,
    1                       AS is_current
FROM source

{% endif %}