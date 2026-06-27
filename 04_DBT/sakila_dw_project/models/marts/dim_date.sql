{{
  config(
    materialized = 'incremental',
    unique_key = 'date_key',
    on_schema_change = 'sync_all_columns'
  )
}}

WITH date_series AS (
    SELECT DATEADD(DAY, number, '2005-01-01') AS dt
    FROM master..spt_values
    WHERE type = 'P'
      AND number BETWEEN 0 AND 730
),
base AS (
    SELECT
        CAST(CONVERT(VARCHAR, dt, 112) AS INT)        AS date_key,
        dt                                             AS date,
        DATEPART(WEEKDAY, dt)                          AS day_of_week,
        DATENAME(WEEKDAY, dt)                          AS day_name,
        DAY(dt)                                        AS day_of_month,
        DATEPART(DAYOFYEAR, dt)                        AS day_of_year,
        DATEPART(WEEK, dt)                             AS week_of_year,
        MONTH(dt)                                      AS month_of_year,
        DATENAME(MONTH, dt)                            AS month_name,
        DATEPART(QUARTER, dt)                          AS quarter_of_year,
        YEAR(dt)                                       AS year,
        CASE WHEN DATEPART(WEEKDAY, dt) IN (1,7)
             THEN 1 ELSE 0 END                         AS is_weekend,
        0                                              AS is_special_day,
        NULL                                           AS special_day_name
    FROM date_series
)
SELECT * FROM base

{% if is_incremental() %}
WHERE date_key NOT IN (SELECT date_key FROM {{ this }})
{% endif %}