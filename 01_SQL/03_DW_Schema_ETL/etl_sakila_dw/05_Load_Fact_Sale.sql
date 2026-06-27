-- ============================================================
-- FILE: 05_Load_Fact_Sale.sql
-- MỤC ĐÍCH: ETL từ Sakila nguồn -> dw.Fact_Sale + Aggregate Fact Tables
-- NGUỒN: sakila.rental, sakila.payment + tất cả Dim đã load
-- GHI CHÚ: Chạy SAU khi đã load xong tất cả Dim
-- SSIS COMPONENT: Execute SQL Task (hoặc Data Flow với Lookup transforms)
-- ============================================================

USE Sakila_DW;
GO

PRINT 'Bắt đầu load Fact_Sale...';

-- -------------------------------------------------------
-- BƯỚC 1: Staging - Extract và Transform từ nguồn Sakila
-- -------------------------------------------------------
IF OBJECT_ID('tempdb..#Stage_Fact', 'U') IS NOT NULL DROP TABLE #Stage_Fact;

-- === SSIS: OLE DB Source query (chạy trên sakila) ===
-- JOIN rental + payment để lấy đầy đủ thông tin giao dịch
SELECT
    r.rental_id,

    -- Date Keys (định dạng YYYYMMDD để match Dim_Date.date_key)
    CAST(FORMAT(r.rental_date,  'yyyyMMdd') AS INT)             AS rental_date_key,
    CASE
        WHEN r.return_date IS NULL THEN -1
        ELSE CAST(FORMAT(r.return_date, 'yyyyMMdd') AS INT)
    END                                                         AS return_date_key,
    CAST(FORMAT(p.payment_date, 'yyyyMMdd') AS INT)             AS payment_date_key,

    -- Natural Keys (để lookup Surrogate Key từ Dim)
    r.customer_id,
    i.film_id,                          -- để lookup product_key
    r.staff_id,
    i.store_id,                         -- cửa hàng từ inventory

    -- Measures
    p.amount,
    f.rental_duration                   AS rental_duration_expected,

    -- Số ngày thuê thực tế
    CASE
        WHEN r.return_date IS NULL THEN NULL
        ELSE DATEDIFF(DAY, r.rental_date, r.return_date)
    END                                                         AS rental_duration_actual,

    -- Số ngày trả trễ
    CASE
        WHEN r.return_date IS NULL THEN 0
        ELSE CASE
            WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
            THEN DATEDIFF(DAY, r.rental_date, r.return_date) - f.rental_duration
            ELSE 0
        END
    END                                                         AS late_days,

    -- Flags
    CASE
        WHEN r.return_date IS NULL THEN 0
        WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration THEN 1
        ELSE 0
    END                                                         AS is_late,

    CASE
        WHEN r.return_date IS NULL THEN 0
        ELSE 1
    END                                                         AS is_returned,

    f.replacement_cost

INTO #Stage_Fact
FROM sakila.dbo.rental r
INNER JOIN sakila.dbo.inventory i
    ON r.inventory_id = i.inventory_id
INNER JOIN sakila.dbo.film f
    ON i.film_id = f.film_id
LEFT JOIN sakila.dbo.payment p
    ON r.rental_id = p.rental_id;

PRINT 'Staging Fact_Sale: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng từ nguồn';

-- -------------------------------------------------------
-- BƯỚC 2: Insert vào Fact_Sale với Surrogate Key lookup
-- (Trong SSIS: dùng Lookup Transform để resolve Surrogate Keys)
-- -------------------------------------------------------

-- Xóa dữ liệu cũ nếu load lại (incremental load thì bỏ TRUNCATE)
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

    -- Lookup customer_key từ Dim_Customer (lấy bản is_current=1)
    dc.customer_key,

    -- Lookup product_key từ Dim_Product (lấy bản is_current=1)
    dp.product_key,

    -- Lookup store_key từ Dim_Geography_Store (lấy bản is_current=1)
    dgs.store_key,

    -- Lookup staff_key từ Dim_Staff (lấy bản is_current=1)
    dst.staff_key,

    -- Measures
    ISNULL(s.amount, 0),
    s.rental_duration_expected,
    s.rental_duration_actual,
    s.late_days,
    s.is_late,
    s.is_returned,
    s.replacement_cost

FROM #Stage_Fact s

-- === LOOKUP JOINS (thay thế cho SSIS Lookup Transform) ===
-- Lookup Dim_Customer
INNER JOIN dw.Dim_Customer dc
    ON s.customer_id = dc.customer_id AND dc.is_current = 1

-- Lookup Dim_Product (SCD2: khớp theo thời điểm giao dịch)
INNER JOIN dw.Dim_Product dp
    ON s.film_id = dp.film_id
    AND dp.is_current = 1   -- Hoặc dùng effective/expiry date nếu cần lịch sử chính xác

-- Lookup Dim_Geography_Store
INNER JOIN dw.Dim_Geography_Store dgs
    ON s.store_id = dgs.store_id AND dgs.is_current = 1

-- Lookup Dim_Staff
INNER JOIN dw.Dim_Staff dst
    ON s.staff_id = dst.staff_id AND dst.is_current = 1

-- Đảm bảo date_key tồn tại trong Dim_Date
INNER JOIN dw.Dim_Date dd_rental   ON s.rental_date_key  = dd_rental.date_key
INNER JOIN dw.Dim_Date dd_payment  ON s.payment_date_key = dd_payment.date_key
-- return_date_key = -1 (chưa trả) hoặc ngày hợp lệ
INNER JOIN dw.Dim_Date dd_return   ON s.return_date_key  = dd_return.date_key;

PRINT 'Insert vào Fact_Sale: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- -------------------------------------------------------
-- BƯỚC 3: Kiểm tra dữ liệu Fact_Sale
-- -------------------------------------------------------
SELECT
    COUNT(*)                    AS TotalTransactions,
    SUM(amount)                 AS TotalRevenue,
    AVG(rental_duration_actual) AS AvgRentalDays,
    SUM(CASE WHEN is_late=1 THEN 1 ELSE 0 END) AS LateReturns,
    SUM(CASE WHEN is_returned=0 THEN 1 ELSE 0 END) AS NotYetReturned
FROM dw.Fact_Sale;

DROP TABLE #Stage_Fact;
GO

-- ============================================================
-- BƯỚC 4: Load Aggregate Fact Tables (từ Fact_Sale chi tiết)
-- ============================================================
PRINT 'Bắt đầu load Aggregate Fact Tables...';

-- --- Fact_Sale_byCustomer ---
TRUNCATE TABLE dw.Fact_Sale_byCustomer;
INSERT INTO dw.Fact_Sale_byCustomer (
    date_key, customer_key, store_key, staff_key,
    total_amount, rental_count, late_count
)
SELECT
    f.rental_date_key       AS date_key,
    f.customer_key,
    f.store_key,
    f.staff_key,
    SUM(f.amount)           AS total_amount,
    COUNT(*)                AS rental_count,
    SUM(f.is_late)          AS late_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.customer_key, f.store_key, f.staff_key;

PRINT 'Fact_Sale_byCustomer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- --- Fact_Sale_byProduct ---
TRUNCATE TABLE dw.Fact_Sale_byProduct;
INSERT INTO dw.Fact_Sale_byProduct (
    date_key, product_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key       AS date_key,
    f.product_key,
    f.store_key,
    SUM(f.amount)           AS total_amount,
    COUNT(*)                AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.product_key, f.store_key;

PRINT 'Fact_Sale_byProduct: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- --- Fact_Sale_byStore ---
TRUNCATE TABLE dw.Fact_Sale_byStore;
INSERT INTO dw.Fact_Sale_byStore (
    date_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key       AS date_key,
    f.store_key,
    SUM(f.amount)           AS total_amount,
    COUNT(*)                AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.store_key;

PRINT 'Fact_Sale_byStore: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- --- Fact_Sale_byStaff ---
TRUNCATE TABLE dw.Fact_Sale_byStaff;
INSERT INTO dw.Fact_Sale_byStaff (
    date_key, store_key, staff_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key       AS date_key,
    f.store_key,
    f.staff_key,
    SUM(f.amount)           AS total_amount,
    COUNT(*)                AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.store_key, f.staff_key;

PRINT 'Fact_Sale_byStaff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- --- Fact_Sale_byDate ---
TRUNCATE TABLE dw.Fact_Sale_byDate;
INSERT INTO dw.Fact_Sale_byDate (
    date_key, customer_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key       AS date_key,
    f.customer_key,
    f.store_key,
    SUM(f.amount)           AS total_amount,
    COUNT(*)                AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.customer_key, f.store_key;

PRINT 'Fact_Sale_byDate: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

PRINT '=== Load Fact_Sale và Aggregate Fact Tables hoàn thành ===';
GO
