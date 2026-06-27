-- ============================================================
-- FILE: 05_Load_Fact_Sale.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Sau khi load xong TẤT CẢ các bảng Dim
-- ============================================================

PRINT 'Bắt đầu load Fact_Sale...';

-- BƯỚC 1: Staging từ nguồn Sakila
IF OBJECT_ID('tempdb..#Stage_Fact', 'U') IS NOT NULL
    DROP TABLE #Stage_Fact;

SELECT
    r.rental_id,

    -- Date Keys (định dạng YYYYMMDD để match Dim_Date.date_key)
    CAST(FORMAT(r.rental_date,  'yyyyMMdd') AS INT)   AS rental_date_key,
    CASE
        WHEN r.return_date IS NULL THEN -1
        ELSE CAST(FORMAT(r.return_date, 'yyyyMMdd') AS INT)
    END                                               AS return_date_key,
    CAST(FORMAT(p.payment_date, 'yyyyMMdd') AS INT)   AS payment_date_key,

    -- Natural Keys dùng để Lookup Surrogate Key
    r.customer_id,
    i.film_id,
    r.staff_id,
    i.store_id,

    -- Measures
    ISNULL(p.amount, 0)                               AS amount,
    f.rental_duration                                 AS rental_duration_expected,

    CASE
        WHEN r.return_date IS NULL THEN NULL
        ELSE DATEDIFF(DAY, r.rental_date, r.return_date)
    END                                               AS rental_duration_actual,

    CASE
        WHEN r.return_date IS NULL THEN 0
        WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
        THEN DATEDIFF(DAY, r.rental_date, r.return_date) - f.rental_duration
        ELSE 0
    END                                               AS late_days,

    CASE
        WHEN r.return_date IS NULL THEN 0
        WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
        THEN 1 ELSE 0
    END                                               AS is_late,

    CASE
        WHEN r.return_date IS NULL THEN 0
        ELSE 1
    END                                               AS is_returned,

    f.replacement_cost

INTO #Stage_Fact
FROM sakila.dbo.rental r
INNER JOIN sakila.dbo.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN sakila.dbo.film f      ON i.film_id      = f.film_id
LEFT JOIN  sakila.dbo.payment p   ON r.rental_id    = p.rental_id;

PRINT 'Staging Fact_Sale: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- BƯỚC 2: Load vào Fact_Sale với Surrogate Key Lookup
TRUNCATE TABLE dw.Fact_Sale;

INSERT INTO dw.Fact_Sale (
    rental_id,
    rental_date_key,
    return_date_key,
    payment_date_key,
    customer_key,
    product_key,
    store_key,
    staff_key,
    amount,
    rental_duration_expected,
    rental_duration_actual,
    late_days,
    is_late,
    is_returned,
    replacement_cost
)
SELECT
    s.rental_id,
    s.rental_date_key,
    s.return_date_key,
    s.payment_date_key,
    dc.customer_key,
    dp.product_key,
    dgs.store_key,
    dst.staff_key,
    s.amount,
    s.rental_duration_expected,
    s.rental_duration_actual,
    s.late_days,
    s.is_late,
    s.is_returned,
    s.replacement_cost
FROM #Stage_Fact s
INNER JOIN dw.Dim_Customer dc
    ON s.customer_id = dc.customer_id AND dc.is_current = 1
INNER JOIN dw.Dim_Product dp
    ON s.film_id = dp.film_id AND dp.is_current = 1
INNER JOIN dw.Dim_Geography_Store dgs
    ON s.store_id = dgs.store_id AND dgs.is_current = 1
INNER JOIN dw.Dim_Staff dst
    ON s.staff_id = dst.staff_id AND dst.is_current = 1
INNER JOIN dw.Dim_Date dd_r  ON s.rental_date_key  = dd_r.date_key
INNER JOIN dw.Dim_Date dd_p  ON s.payment_date_key = dd_p.date_key
INNER JOIN dw.Dim_Date dd_rt ON s.return_date_key  = dd_rt.date_key;

PRINT 'Insert vào Fact_Sale: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

SELECT
    COUNT(*)                                          AS TotalTransactions,
    SUM(amount)                                       AS TotalRevenue,
    AVG(CAST(rental_duration_actual AS FLOAT))        AS AvgRentalDays,
    SUM(CASE WHEN is_late     = 1 THEN 1 ELSE 0 END)  AS LateReturns,
    SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END)  AS NotYetReturned
FROM dw.Fact_Sale;

DROP TABLE #Stage_Fact;
PRINT 'Load Fact_Sale hoàn thành!';
