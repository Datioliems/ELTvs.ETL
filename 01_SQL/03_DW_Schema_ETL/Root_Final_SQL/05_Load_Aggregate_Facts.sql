-- ============================================================
-- FILE: 05_Load_Aggregate_Facts.sql
-- MỤC ĐÍCH: Tổng hợp dữ liệu từ Fact_Sale vào 5 bảng Aggregate
-- CHẠY SAU: DFT Load Fact_Sale hoàn thành
-- CONNECTION: CM_SS_DW
-- ============================================================
USE Sakila_DW;
GO

-- ============================================================
-- 1. Fact_Sale_byCustomer
-- Tổng hợp doanh thu theo khách hàng, cửa hàng, nhân viên, ngày
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byCustomer;

INSERT INTO dw.Fact_Sale_byCustomer (
    date_key, customer_key, store_key, staff_key,
    customer_class, total_amount, rental_count, late_count
)
SELECT
    fs.rental_date_key      AS date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class,
    SUM(fs.amount)          AS total_amount,
    COUNT(*)                AS rental_count,
    SUM(fs.is_late)         AS late_count
FROM dw.Fact_Sale fs
JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class;

PRINT 'Fact_Sale_byCustomer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 2. Fact_Sale_byProduct
-- Tổng hợp doanh thu theo sản phẩm (phim), cửa hàng, ngày
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

PRINT 'Fact_Sale_byProduct: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 3. Fact_Sale_byStore
-- Tổng hợp doanh thu theo cửa hàng, ngày
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

PRINT 'Fact_Sale_byStore: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 4. Fact_Sale_byStaff
-- Tổng hợp doanh thu theo nhân viên, cửa hàng, ngày
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

PRINT 'Fact_Sale_byStaff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 5. Fact_Sale_byDate
-- Tổng hợp doanh thu theo ngày, khách hàng, cửa hàng
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

PRINT 'Fact_Sale_byDate: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- Kiểm tra kết quả tổng thể
-- ============================================================
PRINT '';
PRINT '=== Kiểm tra Aggregate Tables ===';
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
SELECT '--- Fact_Sale (gốc) ---',      COUNT(*) FROM dw.Fact_Sale;
GO
