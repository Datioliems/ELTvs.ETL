-- ============================================================
-- FILE: Test_Pipeline_Minh_Chung.sql
-- MỤC ĐÍCH: Kịch bản test đầy đủ để chứng minh pipeline ETL
--           hoạt động thành công — dùng làm minh chứng báo cáo
-- CHẠY TRONG: SSMS (kết nối SQL Server)
-- ============================================================

USE Sakila_DW;
GO

PRINT '============================================================';
PRINT 'KIỂM TRA ETL PIPELINE — SAKILA DATA WAREHOUSE';
PRINT 'Thời gian: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '============================================================';

-- ============================================================
-- PHẦN 1: KIỂM TRA SỐ DÒNG (chụp màn hình kết quả)
-- ============================================================
PRINT '';
PRINT '---------- PHẦN 1: SỐ DÒNG TỪNG BẢNG ----------';

SELECT
    bang,
    so_dong,
    CASE
        WHEN bang = 'Dim_Date'            AND so_dong >= 11323 THEN '✓ ĐẠT'
        WHEN bang = 'Dim_Customer'        AND so_dong = 599    THEN '✓ ĐẠT'
        WHEN bang = 'Dim_Product'         AND so_dong = 1000   THEN '✓ ĐẠT'
        WHEN bang = 'Dim_Staff'           AND so_dong = 2      THEN '✓ ĐẠT'
        WHEN bang = 'Dim_Geography_Store' AND so_dong = 2      THEN '✓ ĐẠT'
        WHEN bang = 'Fact_Sale'           AND so_dong > 0      THEN '✓ ĐẠT'
        ELSE '✗ CẦN KIỂM TRA'
    END AS ket_qua
FROM (
    SELECT 'Dim_Date'            AS bang, COUNT(*) AS so_dong FROM dw.Dim_Date
    UNION ALL
    SELECT 'Dim_Customer',                COUNT(*) FROM dw.Dim_Customer        WHERE is_current = 1
    UNION ALL
    SELECT 'Dim_Product',                 COUNT(*) FROM dw.Dim_Product          WHERE is_current = 1
    UNION ALL
    SELECT 'Dim_Staff',                   COUNT(*) FROM dw.Dim_Staff            WHERE is_current = 1
    UNION ALL
    SELECT 'Dim_Geography_Store',         COUNT(*) FROM dw.Dim_Geography_Store  WHERE is_current = 1
    UNION ALL
    SELECT 'Fact_Sale',                   COUNT(*) FROM dw.Fact_Sale
) x
ORDER BY bang;
GO

-- ============================================================
-- PHẦN 2: KỊCH BẢN TEST SCD TYPE 2 — THAY ĐỔI KHÁCH HÀNG
-- Chứng minh: khi email khách hàng thay đổi → DW lưu lịch sử
-- ============================================================
PRINT '';
PRINT '---------- PHẦN 2: TEST SCD TYPE 2 — THAY ĐỔI KHÁCH HÀNG ----------';

-- Bước 2.1: Xem trạng thái TRƯỚC khi thay đổi
PRINT '--- TRƯỚC KHI THAY ĐỔI ---';
SELECT
    customer_key,
    customer_id,
    full_name,
    email,
    city,
    country,
    customer_class,
    effective_date,
    expiry_date,
    is_current
FROM dw.Dim_Customer
WHERE customer_id = 1   -- MARY SMITH làm mẫu
ORDER BY effective_date;
GO

-- Bước 2.2: Thay đổi city của customer_id = 1 trong nguồn
-- (simulate khách hàng chuyển địa chỉ)
PRINT '';
PRINT '--- THAY ĐỔI: Cập nhật email customer_id = 1 trong Sakila_CRM ---';

UPDATE Sakila_CRM.dbo.customer
SET email = 'MARY.SMITH.NEW@sakilacustomer.org'
WHERE customer_id = 1;

SELECT customer_id, email FROM Sakila_CRM.dbo.customer WHERE customer_id = 1;
GO

-- Bước 2.3: Hướng dẫn chạy lại ETL
PRINT '';
PRINT '*** HÀNH ĐỘNG: Chạy lại SSIS Package (DFT Load Dim_Customer) ***';
PRINT '*** Sau khi chạy xong, tiếp tục query bên dưới ***';
GO

-- Bước 2.4: Kiểm tra SAU KHI chạy lại ETL
-- (chạy phần này sau khi SSIS đã chạy xong)
PRINT '';
PRINT '--- SAU KHI CHẠY LẠI ETL ---';
SELECT
    customer_key,
    customer_id,
    full_name,
    email,
    effective_date,
    expiry_date,
    is_current,
    CASE WHEN is_current = 1 THEN '→ BẢN GHI HIỆN TẠI'
         ELSE '→ LỊCH SỬ (đã đóng)'
    END AS trang_thai
FROM dw.Dim_Customer
WHERE customer_id = 1
ORDER BY effective_date;

-- Đánh giá SCD2
DECLARE @cnt INT = (SELECT COUNT(*) FROM dw.Dim_Customer WHERE customer_id = 1);
PRINT CASE WHEN @cnt >= 2
    THEN '✓ SCD Type 2 ĐÚNG: ' + CAST(@cnt AS VARCHAR) + ' bản ghi (1 lịch sử + 1 hiện tại)'
    ELSE '✗ SCD Type 2 CHƯA ĐÚNG: chỉ có ' + CAST(@cnt AS VARCHAR) + ' bản ghi'
END;
GO

-- Bước 2.5: Khôi phục dữ liệu gốc
PRINT '';
PRINT '--- KHÔI PHỤC dữ liệu gốc ---';
UPDATE Sakila_CRM.dbo.customer
SET email = 'MARY.SMITH@sakilacustomer.org'
WHERE customer_id = 1;
PRINT 'Đã khôi phục email gốc.';
GO

-- ============================================================
-- PHẦN 3: KỊCH BẢN TEST THÊM DỮ LIỆU MỚI
-- Chứng minh: thêm khách hàng mới → xuất hiện trong DW
-- ============================================================
PRINT '';
PRINT '---------- PHẦN 3: TEST THÊM DỮ LIỆU MỚI ----------';

-- Bước 3.1: Thêm customer mới vào nguồn
PRINT '--- Thêm customer mới vào Sakila_CRM ---';
INSERT INTO Sakila_CRM.dbo.customer (
    first_name, last_name, email,
    address_id, store_id, active, create_date
)
VALUES (
    'Nhom', 'Chin',
    'nhom9.test@sakila.com',
    1, 1, 1, GETDATE()
);

DECLARE @new_id INT = SCOPE_IDENTITY();
PRINT 'Đã thêm customer_id = ' + CAST(@new_id AS VARCHAR);

SELECT customer_id, first_name, last_name, email
FROM Sakila_CRM.dbo.customer
WHERE customer_id = @new_id;
GO

-- Bước 3.2: Hướng dẫn chạy lại ETL
PRINT '';
PRINT '*** HÀNH ĐỘNG: Chạy lại SSIS Package (DFT Load Dim_Customer) ***';
GO

-- Bước 3.3: Kiểm tra khách hàng mới đã vào DW chưa
PRINT '';
PRINT '--- Kiểm tra customer mới trong DW ---';
SELECT
    customer_key,
    customer_id,
    full_name,
    email,
    effective_date,
    is_current
FROM dw.Dim_Customer
WHERE email = 'nhom9.test@sakila.com';

-- Đánh giá
DECLARE @new_cust INT = (SELECT COUNT(*) FROM dw.Dim_Customer WHERE email = 'nhom9.test@sakila.com');
PRINT CASE WHEN @new_cust = 1
    THEN '✓ INSERT MỚI ĐÚNG: customer mới đã xuất hiện trong DW'
    ELSE '✗ CHƯA CÓ: customer mới chưa vào DW'
END;
GO

-- Bước 3.4: Dọn dẹp — xóa customer test
PRINT '';
PRINT '--- Dọn dẹp: xóa customer test ---';
DELETE FROM Sakila_CRM.dbo.customer
WHERE email = 'nhom9.test@sakila.com';
PRINT 'Đã xóa customer test khỏi nguồn.';
PRINT '(Bản ghi trong DW vẫn giữ nguyên — đây là expected behavior)';
GO

-- ============================================================
-- PHẦN 4: KIỂM TRA CHẤT LƯỢNG DỮ LIỆU FACT_SALE
-- ============================================================
PRINT '';
PRINT '---------- PHẦN 4: CHẤT LƯỢNG DỮ LIỆU FACT_SALE ----------';

SELECT
    kiem_tra,
    so_dong,
    CASE WHEN so_dong = 0 THEN '✓ ĐẠT' ELSE '✗ CÓ VẤN ĐỀ' END AS ket_qua
FROM (
    SELECT 'Orphan customer_key'   AS kiem_tra,
        COUNT(*) AS so_dong
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Customer d WHERE d.customer_key = f.customer_key)
    UNION ALL
    SELECT 'Orphan product_key',
        COUNT(*)
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Product d WHERE d.product_key = f.product_key)
    UNION ALL
    SELECT 'Orphan store_key',
        COUNT(*)
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Geography_Store d WHERE d.store_key = f.store_key)
    UNION ALL
    SELECT 'Orphan staff_key',
        COUNT(*)
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Staff d WHERE d.staff_key = f.staff_key)
    UNION ALL
    SELECT 'Orphan rental_date_key',
        COUNT(*)
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Date d WHERE d.date_key = f.rental_date_key)
    UNION ALL
    SELECT 'Orphan return_date_key (kể cả -1)',
        COUNT(*)
    FROM dw.Fact_Sale f
    WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Date d WHERE d.date_key = f.return_date_key)
    UNION ALL
    SELECT 'Số lượt chưa trả (return_date_key = -1)',
        COUNT(*)
    FROM dw.Fact_Sale WHERE return_date_key = -1
) x;
GO

-- ============================================================
-- PHẦN 5: THỐNG KÊ NHANH ĐỂ CHỤP MINH CHỨNG
-- ============================================================
PRINT '';
PRINT '---------- PHẦN 5: THỐNG KÊ TỔNG QUAN ----------';

SELECT
    dd.year                                     AS nam,
    dd.month_name                               AS thang,
    COUNT(*)                                    AS so_luot_thue,
    SUM(fs.amount)                              AS doanh_thu,
    COUNT(CASE WHEN fs.is_returned = 0 THEN 1 END) AS chua_tra,
    COUNT(CASE WHEN fs.is_late = 1 THEN 1 END)     AS tra_tre
FROM dw.Fact_Sale fs
JOIN dw.Dim_Date dd ON fs.rental_date_key = dd.date_key
WHERE dd.year IN (2005, 2006)
GROUP BY dd.year, dd.month_of_year, dd.month_name
ORDER BY dd.year, dd.month_of_year;
GO

PRINT '';
PRINT '============================================================';
PRINT 'HOÀN THÀNH KIỂM TRA — Chụp màn hình kết quả làm minh chứng';
PRINT '============================================================';
GO
