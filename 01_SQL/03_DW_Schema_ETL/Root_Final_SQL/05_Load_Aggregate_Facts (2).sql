-- ============================================================
-- FILE: 05_Load_Aggregate_Facts.sql
-- FIX: CAST(is_late AS INT) và CAST(is_returned AS INT)
--      trước khi SUM vì kiểu BIT không SUM trực tiếp được
-- CONNECTION: CM_SS_DW
-- ============================================================
USE Sakila_DW;
GO

PRINT 'Bắt đầu load Aggregate Facts: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- ============================================================
-- 1. Fact_Sale_byCustomer
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byCustomer;

INSERT INTO dw.Fact_Sale_byCustomer (
    date_key, customer_key, store_key, staff_key,
    customer_class, total_amount, rental_count, late_count
)
SELECT
    fs.rental_date_key          AS date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class,
    SUM(fs.amount)              AS total_amount,
    COUNT(*)                    AS rental_count,
    SUM(CAST(fs.is_late AS INT)) AS late_count   -- FIX: BIT → INT
FROM dw.Fact_Sale fs
JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
                       AND dc.is_current   = 1
GROUP BY
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class;

PRINT '+ Fact_Sale_byCustomer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 2. Fact_Sale_byProduct
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byProduct;

INSERT INTO dw.Fact_Sale_byProduct (
    date_key, product_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.product_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.product_key,
    fs.store_key;

PRINT '+ Fact_Sale_byProduct: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 3. Fact_Sale_byStore
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byStore;

INSERT INTO dw.Fact_Sale_byStore (
    date_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.store_key;

PRINT '+ Fact_Sale_byStore: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 4. Fact_Sale_byStaff
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byStaff;

INSERT INTO dw.Fact_Sale_byStaff (
    date_key, store_key, staff_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.store_key,
    fs.staff_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.store_key,
    fs.staff_key;

PRINT '+ Fact_Sale_byStaff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 5. Fact_Sale_byDate
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byDate;

INSERT INTO dw.Fact_Sale_byDate (
    date_key, customer_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.customer_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key;

PRINT '+ Fact_Sale_byDate: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- Kiểm tra kết quả
-- ============================================================
PRINT '';
PRINT '=== Tổng kết Aggregate Tables ===';
SELECT 'Fact_Sale_byCustomer' AS bang, COUNT(*) AS so_dong FROM dw.Fact_Sale_byCustomer
UNION ALL
SELECT 'Fact_Sale_byProduct',          COUNT(*) FROM dw.Fact_Sale_byProduct
UNION ALL
SELECT 'Fact_Sale_byStore',            COUNT(*) FROM dw.Fact_Sale_byStore
UNION ALL
SELECT 'Fact_Sale_byStaff',            COUNT(*) FROM dw.Fact_Sale_byStaff
UNION ALL
SELECT 'Fact_Sale_byDate',             COUNT(*) FROM dw.Fact_Sale_byDate
UNION ALL
SELECT '--- Fact_Sale (goc) ---',      COUNT(*) FROM dw.Fact_Sale;

PRINT 'Hoàn thành: ' + CONVERT(VARCHAR, GETDATE(), 120);
GO
