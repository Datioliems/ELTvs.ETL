-- ============================================================
-- FILE: 06_Master_ETL_And_Views.sql
-- MỤC ĐÍCH:
--   A. Script master gọi toàn bộ ETL pipeline theo thứ tự
--   B. Tạo Views cho Role-Playing Dimension (Dim_Date x3)
--   C. Kiểm tra kết quả toàn bộ kho dữ liệu
-- ============================================================

USE Sakila_DW;
GO

-- ============================================================
-- PHẦN A: ROLE-PLAYING DIMENSION VIEWS
-- Tạo 3 VIEW từ Dim_Date để phân biệt vai trò trong Fact_Sale
-- ============================================================

-- View 1: Ngày thuê
IF OBJECT_ID('dw.Dim_RentalDate', 'V') IS NOT NULL DROP VIEW dw.Dim_RentalDate;
GO
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
FROM dw.Dim_Date;
GO

-- View 2: Ngày trả đĩa
IF OBJECT_ID('dw.Dim_ReturnDate', 'V') IS NOT NULL DROP VIEW dw.Dim_ReturnDate;
GO
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
FROM dw.Dim_Date;
GO

-- View 3: Ngày thanh toán
IF OBJECT_ID('dw.Dim_PaymentDate', 'V') IS NOT NULL DROP VIEW dw.Dim_PaymentDate;
GO
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
FROM dw.Dim_Date;
GO

PRINT 'Đã tạo 3 Role-Playing Dimension Views cho Dim_Date';

-- ============================================================
-- PHẦN B: SCRIPT MASTER - Gọi ETL theo thứ tự đúng
-- Dùng làm "Execute SQL Task" trong SSIS Control Flow
-- ============================================================
/*
    HƯỚNG DẪN CHẠY:
    Thứ tự thực thi BẮTBUỘC:
    1. 01_Create_DW_Schema.sql       -- Tạo schema (chỉ chạy 1 lần)
    2. 02_Load_Dim_Date.sql          -- Sinh ngày (chỉ cần chạy 1 lần hoặc hàng năm)
    3. 04_Load_Dim_Staff_Customer_Store.sql (Phần C: Dim_Geography_Store trước)
    4. 04_Load_Dim_Staff_Customer_Store.sql (Phần A: Dim_Staff)
    5. 04_Load_Dim_Staff_Customer_Store.sql (Phần B: Dim_Customer)
    6. 03_Load_Dim_Product.sql
    7. 05_Load_Fact_Sale.sql         -- Fact phải chạy SAU tất cả Dim

    Trong SSIS Control Flow Package, cấu trúc như sau:
    [Sequence Container: Load Dims]
        -> Execute SQL: Load Dim_Date
        -> Execute SQL: Load Dim_Geography_Store
        -> Execute SQL: Load Dim_Staff
        -> Execute SQL: Load Dim_Customer
        -> Execute SQL: Load Dim_Product
    [Execute SQL: Load Fact_Sale]   (chạy sau Sequence Container)
    [Execute SQL: Load Aggregate Facts]
*/

-- ============================================================
-- PHẦN C: KIỂM TRA KẾT QUẢ SAU KHI LOAD XONG
-- ============================================================

-- Tổng quan số dòng trong tất cả các bảng
SELECT 'dw.Dim_Date'               AS TableName, COUNT(*) AS RowCount FROM dw.Dim_Date
UNION ALL
SELECT 'dw.Dim_Product (current)'  , COUNT(*) FROM dw.Dim_Product WHERE is_current=1
UNION ALL
SELECT 'dw.Dim_Product (total)'    , COUNT(*) FROM dw.Dim_Product
UNION ALL
SELECT 'dw.Dim_Staff (current)'    , COUNT(*) FROM dw.Dim_Staff WHERE is_current=1
UNION ALL
SELECT 'dw.Dim_Customer (current)' , COUNT(*) FROM dw.Dim_Customer WHERE is_current=1
UNION ALL
SELECT 'dw.Dim_Geography_Store'    , COUNT(*) FROM dw.Dim_Geography_Store WHERE is_current=1
UNION ALL
SELECT 'dw.Fact_Sale'              , COUNT(*) FROM dw.Fact_Sale
UNION ALL
SELECT 'dw.Fact_Sale_byCustomer'   , COUNT(*) FROM dw.Fact_Sale_byCustomer
UNION ALL
SELECT 'dw.Fact_Sale_byProduct'    , COUNT(*) FROM dw.Fact_Sale_byProduct
UNION ALL
SELECT 'dw.Fact_Sale_byStore'      , COUNT(*) FROM dw.Fact_Sale_byStore
UNION ALL
SELECT 'dw.Fact_Sale_byStaff'      , COUNT(*) FROM dw.Fact_Sale_byStaff
UNION ALL
SELECT 'dw.Fact_Sale_byDate'       , COUNT(*) FROM dw.Fact_Sale_byDate;
GO

-- ============================================================
-- PHẦN D: MẪU TRUY VẤN PHÂN TÍCH (Kiểm tra DW hoạt động đúng)
-- ============================================================

-- Q1: Doanh thu theo thể loại phim theo năm
SELECT
    dd.year                     AS nam,
    dp.category_name            AS the_loai,
    SUM(fs.amount)              AS doanh_thu,
    COUNT(*)                    AS so_luot_thue
FROM dw.Fact_Sale fs
INNER JOIN dw.Dim_RentalDate    dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Product       dp  ON fs.product_key = dp.product_key
GROUP BY dd.year, dp.category_name
ORDER BY dd.year, doanh_thu DESC;
GO

-- Q2: Doanh thu theo cửa hàng theo tháng
SELECT
    dd.year                     AS nam,
    dd.month_name               AS thang,
    dgs.city                    AS cua_hang,
    SUM(fs.amount)              AS doanh_thu,
    COUNT(*)                    AS so_giao_dich
FROM dw.Fact_Sale fs
INNER JOIN dw.Dim_RentalDate        dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Geography_Store   dgs ON fs.store_key = dgs.store_key
GROUP BY dd.year, dd.month_of_year, dd.month_name, dgs.city
ORDER BY dd.year, dd.month_of_year, dgs.city;
GO

-- Q3: Top 10 nhân viên có doanh thu cao nhất
SELECT TOP 10
    dst.full_name               AS nhan_vien,
    dst.store_name              AS chi_nhanh,
    SUM(fs.amount)              AS tong_doanh_thu,
    COUNT(*)                    AS so_giao_dich
FROM dw.Fact_Sale fs
INNER JOIN dw.Dim_Staff dst ON fs.staff_key = dst.staff_key
GROUP BY dst.full_name, dst.store_name
ORDER BY tong_doanh_thu DESC;
GO

-- Q4: Phân tích trả trễ theo thể loại phim
SELECT
    dp.category_name            AS the_loai,
    COUNT(*)                    AS tong_giao_dich,
    SUM(fs.is_late)             AS so_lan_tre,
    CAST(SUM(fs.is_late)*100.0/COUNT(*) AS DECIMAL(5,2)) AS ty_le_tre_pct,
    AVG(CAST(fs.late_days AS FLOAT))  AS tb_ngay_tre
FROM dw.Fact_Sale fs
INNER JOIN dw.Dim_Product dp ON fs.product_key = dp.product_key
WHERE fs.is_returned = 1
GROUP BY dp.category_name
ORDER BY so_lan_tre DESC;
GO

-- Q5: Phân hạng khách hàng (Vàng/Bạc/Đồng)
SELECT
    dc.customer_class           AS hang_khach,
    COUNT(DISTINCT fs.customer_key) AS so_khach,
    SUM(fs.amount)              AS tong_doanh_thu,
    AVG(fs.amount)              AS tb_moi_giao_dich
FROM dw.Fact_Sale fs
INNER JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_class
ORDER BY tong_doanh_thu DESC;
GO

PRINT '=== Tất cả scripts ETL và Views đã sẵn sàng ===';
GO
