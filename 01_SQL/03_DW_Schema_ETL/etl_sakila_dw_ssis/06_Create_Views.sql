-- ============================================================
-- FILE: 06_Create_Views.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Sau tất cả các bước load (chỉ cần chạy 1 lần)
-- MỤC ĐÍCH: Tạo 3 Role-Playing Dimension Views cho Dim_Date
-- ============================================================

-- View 1: Ngày thuê
IF OBJECT_ID('dw.Dim_RentalDate', 'V') IS NOT NULL
    DROP VIEW dw.Dim_RentalDate;

EXEC('
CREATE VIEW dw.Dim_RentalDate AS
SELECT
    date_key        AS rental_date_key,
    date            AS rental_date,
    day_of_week     AS rental_day_of_week,
    day_name        AS rental_day_name,
    day_of_month    AS rental_day_of_month,
    month_of_year   AS rental_month,
    month_name      AS rental_month_name,
    quarter_of_year AS rental_quarter,
    year            AS rental_year,
    is_weekend      AS rental_is_weekend,
    is_special_day  AS rental_is_special_day,
    special_day     AS rental_special_day
FROM dw.Dim_Date
');

PRINT 'Đã tạo View: dw.Dim_RentalDate';

-- View 2: Ngày trả đĩa
IF OBJECT_ID('dw.Dim_ReturnDate', 'V') IS NOT NULL
    DROP VIEW dw.Dim_ReturnDate;

EXEC('
CREATE VIEW dw.Dim_ReturnDate AS
SELECT
    date_key        AS return_date_key,
    date            AS return_date,
    day_of_week     AS return_day_of_week,
    day_name        AS return_day_name,
    day_of_month    AS return_day_of_month,
    month_of_year   AS return_month,
    month_name      AS return_month_name,
    quarter_of_year AS return_quarter,
    year            AS return_year,
    is_weekend      AS return_is_weekend,
    is_special_day  AS return_is_special_day,
    special_day     AS return_special_day
FROM dw.Dim_Date
');

PRINT 'Đã tạo View: dw.Dim_ReturnDate';

-- View 3: Ngày thanh toán
IF OBJECT_ID('dw.Dim_PaymentDate', 'V') IS NOT NULL
    DROP VIEW dw.Dim_PaymentDate;

EXEC('
CREATE VIEW dw.Dim_PaymentDate AS
SELECT
    date_key        AS payment_date_key,
    date            AS payment_date,
    day_of_week     AS payment_day_of_week,
    day_name        AS payment_day_name,
    day_of_month    AS payment_day_of_month,
    month_of_year   AS payment_month,
    month_name      AS payment_month_name,
    quarter_of_year AS payment_quarter,
    year            AS payment_year,
    is_weekend      AS payment_is_weekend,
    is_special_day  AS payment_is_special_day,
    special_day     AS payment_special_day
FROM dw.Dim_Date
');

PRINT 'Đã tạo View: dw.Dim_PaymentDate';

-- Kiểm tra tổng quan tất cả bảng sau khi load xong
SELECT 'dw.Dim_Date'                AS TableName,
       COUNT(*)                     AS RowCount
FROM dw.Dim_Date
UNION ALL
SELECT 'dw.Dim_Product (current)',   COUNT(*) FROM dw.Dim_Product          WHERE is_current = 1
UNION ALL
SELECT 'dw.Dim_Product (total)',     COUNT(*) FROM dw.Dim_Product
UNION ALL
SELECT 'dw.Dim_Staff (current)',     COUNT(*) FROM dw.Dim_Staff            WHERE is_current = 1
UNION ALL
SELECT 'dw.Dim_Customer (current)',  COUNT(*) FROM dw.Dim_Customer         WHERE is_current = 1
UNION ALL
SELECT 'dw.Dim_Geography_Store',     COUNT(*) FROM dw.Dim_Geography_Store  WHERE is_current = 1
UNION ALL
SELECT 'dw.Fact_Sale',               COUNT(*) FROM dw.Fact_Sale
UNION ALL
SELECT 'dw.Fact_Sale_byCustomer',    COUNT(*) FROM dw.Fact_Sale_byCustomer
UNION ALL
SELECT 'dw.Fact_Sale_byProduct',     COUNT(*) FROM dw.Fact_Sale_byProduct
UNION ALL
SELECT 'dw.Fact_Sale_byStore',       COUNT(*) FROM dw.Fact_Sale_byStore
UNION ALL
SELECT 'dw.Fact_Sale_byStaff',       COUNT(*) FROM dw.Fact_Sale_byStaff
UNION ALL
SELECT 'dw.Fact_Sale_byDate',        COUNT(*) FROM dw.Fact_Sale_byDate;

PRINT 'Tạo Views và kiểm tra hoàn thành!';
