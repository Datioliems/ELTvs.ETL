USE dwh;

INSERT INTO Fact_Sale (
    rental_id,
    rental_date_key, return_date_key, payment_date_key,
    customer_key, product_key, store_key, staff_key,
    amount,
    rental_duration_expected,
    rental_duration_actual,
    late_days,
    is_late,
    is_returned,
    replacement_cost
)
SELECT
    r.rental_id,
    COALESCE(d_r.date_key,   -1),
    COALESCE(d_ret.date_key, -1),
    COALESCE(d_p.date_key,   -1),
    dc.customer_key,
    dp.product_key,
    dg.store_key,
    ds.staff_key,
    p_agg.total_amount,
    f.rental_duration,
    DATEDIFF(r.return_date, r.rental_date),
    CASE
        WHEN r.return_date IS NULL THEN NULL
        ELSE GREATEST(0, DATEDIFF(r.return_date,
             DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)))
    END,
    CASE
        WHEN r.return_date IS NOT NULL
         AND DATEDIFF(r.return_date,
             DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)) > 0
        THEN 1 ELSE 0
    END,
    IF(r.return_date IS NOT NULL, 1, 0),
    f.replacement_cost
FROM sakila.rental r
JOIN (
    SELECT rental_id,
           SUM(amount)       AS total_amount,
           MIN(payment_date) AS payment_date
    FROM sakila.payment
    GROUP BY rental_id
) p_agg ON r.rental_id = p_agg.rental_id
JOIN sakila.inventory        i    ON r.inventory_id = i.inventory_id
JOIN sakila.film             f    ON i.film_id      = f.film_id
JOIN dwh.Dim_Date            d_r  ON DATE(r.rental_date)      = d_r.date
LEFT JOIN dwh.Dim_Date       d_ret ON DATE(r.return_date)     = d_ret.date
JOIN dwh.Dim_Date            d_p  ON DATE(p_agg.payment_date) = d_p.date
JOIN dwh.Dim_Customer        dc   ON r.customer_id = dc.customer_id  AND dc.is_current = 1
JOIN dwh.Dim_Product         dp   ON i.film_id     = dp.film_id      AND dp.is_active  = 1
JOIN dwh.Dim_Geography_Store dg   ON i.store_id    = dg.store_id
JOIN dwh.Dim_Staff           ds   ON r.staff_id    = ds.staff_id     AND ds.is_current = 1;

-- Kiểm tra ngay sau khi insert
SELECT COUNT(*) AS fact_sale_rows FROM Fact_Sale;
