-- ============================================================
-- FILE: 05B_Load_Aggregate_Facts.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Sau 05_Load_Fact_Sale.sql
-- ============================================================

PRINT 'Bắt đầu load Aggregate Fact Tables...';

-- Fact_Sale_byCustomer
TRUNCATE TABLE dw.Fact_Sale_byCustomer;

INSERT INTO dw.Fact_Sale_byCustomer (
    date_key, customer_key, store_key, staff_key,
    total_amount, rental_count, late_count
)
SELECT
    f.rental_date_key  AS date_key,
    f.customer_key,
    f.store_key,
    f.staff_key,
    SUM(f.amount)      AS total_amount,
    COUNT(*)           AS rental_count,
    SUM(f.is_late)     AS late_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.customer_key, f.store_key, f.staff_key;

PRINT 'Fact_Sale_byCustomer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- Fact_Sale_byProduct
TRUNCATE TABLE dw.Fact_Sale_byProduct;

INSERT INTO dw.Fact_Sale_byProduct (
    date_key, product_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key  AS date_key,
    f.product_key,
    f.store_key,
    SUM(f.amount)      AS total_amount,
    COUNT(*)           AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.product_key, f.store_key;

PRINT 'Fact_Sale_byProduct: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- Fact_Sale_byStore
TRUNCATE TABLE dw.Fact_Sale_byStore;

INSERT INTO dw.Fact_Sale_byStore (
    date_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key  AS date_key,
    f.store_key,
    SUM(f.amount)      AS total_amount,
    COUNT(*)           AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.store_key;

PRINT 'Fact_Sale_byStore: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- Fact_Sale_byStaff
TRUNCATE TABLE dw.Fact_Sale_byStaff;

INSERT INTO dw.Fact_Sale_byStaff (
    date_key, store_key, staff_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key  AS date_key,
    f.store_key,
    f.staff_key,
    SUM(f.amount)      AS total_amount,
    COUNT(*)           AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.store_key, f.staff_key;

PRINT 'Fact_Sale_byStaff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- Fact_Sale_byDate
TRUNCATE TABLE dw.Fact_Sale_byDate;

INSERT INTO dw.Fact_Sale_byDate (
    date_key, customer_key, store_key,
    total_amount, rental_count
)
SELECT
    f.rental_date_key  AS date_key,
    f.customer_key,
    f.store_key,
    SUM(f.amount)      AS total_amount,
    COUNT(*)           AS rental_count
FROM dw.Fact_Sale f
GROUP BY f.rental_date_key, f.customer_key, f.store_key;

PRINT 'Fact_Sale_byDate: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

PRINT 'Load tất cả Aggregate Fact Tables hoàn thành!';
