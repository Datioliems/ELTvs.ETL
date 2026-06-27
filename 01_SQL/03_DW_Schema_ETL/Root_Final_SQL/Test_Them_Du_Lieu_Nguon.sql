-- ============================================================
-- FILE: Test_Them_Du_Lieu_Nguon.sql
-- MỤC ĐÍCH: Thêm dữ liệu mới vào OLTP rồi kiểm tra DW cập nhật
-- KỊCH BẢN:
--   KB1: Thêm khách hàng mới → DW phải có customer mới
--   KB2: Thêm giao dịch thuê mới → DW phải có Fact_Sale mới
--   KB3: Thay đổi email khách hàng → DW phải lưu lịch sử SCD2
-- ============================================================

-- ============================================================
-- BƯỚC 0: CHỤP TRẠNG THÁI TRƯỚC KHI THÊM DỮ LIỆU
-- Chạy phần này TRƯỚC khi thêm bất kỳ gì
-- ============================================================
USE Sakila_DW;
GO

PRINT '=== TRẠNG THÁI TRƯỚC KHI THÊM DỮ LIỆU ===';
SELECT
    'Dim_Customer'        AS bang, COUNT(*) AS so_dong FROM dw.Dim_Customer WHERE is_current = 1
UNION ALL SELECT 'Fact_Sale',     COUNT(*) FROM dw.Fact_Sale
UNION ALL SELECT 'Dim_Product',   COUNT(*) FROM dw.Dim_Product WHERE is_current = 1;
GO

-- ============================================================
-- KỊCH BẢN 1: THÊM KHÁCH HÀNG MỚI
-- Chạy phần này trong MySQL Workbench (sakila_crm)
-- hoặc SSMS (Sakila_CRM)
-- ============================================================

/*
==== CHẠY TRONG MySQL Workbench (sakila_crm) ====

INSERT INTO customer (
    store_id, first_name, last_name, email,
    address_id, active, create_date
) VALUES
    (1, 'An', 'Nguyen', 'an.nguyen@test.com', 1, 1, NOW()),
    (2, 'Binh', 'Tran', 'binh.tran@test.com', 2, 1, NOW()),
    (1, 'Chi', 'Le', 'chi.le@test.com',    1, 1, NOW());

-- Ghi lại customer_id mới sinh ra:
SELECT customer_id, first_name, last_name, email
FROM customer
WHERE email IN ('an.nguyen@test.com','binh.tran@test.com','chi.le@test.com');
*/

-- ==== HOẶC CHẠY TRONG SSMS (Sakila_CRM SQL Server) ====
USE Sakila_CRM;
GO

INSERT INTO dbo.customer (
    store_id, first_name, last_name, email,
    address_id, active, create_date
) VALUES
    (1, N'An',   N'Nguyen', N'an.nguyen@test.com',  1, 'Y', GETDATE()),
    (2, N'Binh', N'Tran',   N'binh.tran@test.com',  2, 'Y', GETDATE()),
    (1, N'Chi',  N'Le',     N'chi.le@test.com',     1, 'Y', GETDATE());

-- Xem customer_id được sinh ra
SELECT customer_id, first_name, last_name, email, store_id
FROM dbo.customer
WHERE email IN ('an.nguyen@test.com','binh.tran@test.com','chi.le@test.com');
GO

-- ============================================================
-- KỊCH BẢN 2: THÊM GIAO DỊCH THUÊ MỚI
-- Thêm vào Sakila_Sales để có Fact_Sale mới
-- ============================================================
USE Sakila_Sales;
GO

-- Lấy customer_id mới vừa insert
DECLARE @cust1 INT = (SELECT customer_id FROM Sakila_CRM.dbo.customer WHERE email = 'an.nguyen@test.com');
DECLARE @cust2 INT = (SELECT customer_id FROM Sakila_CRM.dbo.customer WHERE email = 'binh.tran@test.com');
DECLARE @cust3 INT = (SELECT customer_id FROM Sakila_CRM.dbo.customer WHERE email = 'chi.le@test.com');

-- Thêm giao dịch thuê (rental)
-- inventory_id: dùng ID có sẵn trong Sakila_Inventory
INSERT INTO dbo.rental (rental_date, inventory_id, customer_id, staff_id, return_date)
VALUES
    (GETDATE(), 1,  @cust1, 1, DATEADD(DAY, 3, GETDATE())),  -- An thuê, đã trả
    (GETDATE(), 2,  @cust2, 2, NULL),                         -- Binh thuê, chưa trả
    (GETDATE(), 3,  @cust3, 1, DATEADD(DAY, 7, GETDATE()));   -- Chi thuê, trả muộn

-- Xem rental_id mới
DECLARE @r1 INT, @r2 INT, @r3 INT;
SELECT TOP 3 @r1 = rental_id FROM dbo.rental WHERE customer_id = @cust1 ORDER BY rental_id DESC;
SELECT TOP 3 @r2 = rental_id FROM dbo.rental WHERE customer_id = @cust2 ORDER BY rental_id DESC;
SELECT TOP 3 @r3 = rental_id FROM dbo.rental WHERE customer_id = @cust3 ORDER BY rental_id DESC;

-- Thêm thanh toán cho rental
INSERT INTO dbo.payment (customer_id, staff_id, rental_id, amount, payment_date)
VALUES
    (@cust1, 1, @r1, 4.99,  GETDATE()),
    (@cust3, 1, @r3, 9.99,  GETDATE());
-- Binh chưa thanh toán (return_date = NULL, không có payment)

SELECT rental_id, customer_id, inventory_id, rental_date, return_date
FROM dbo.rental
WHERE customer_id IN (@cust1, @cust2, @cust3)
ORDER BY rental_id;
GO

-- ============================================================
-- KỊCH BẢN 3: THAY ĐỔI EMAIL (test SCD Type 2)
-- ============================================================
USE Sakila_CRM;
GO

PRINT '--- Thay đổi email của An Nguyen ---';
UPDATE dbo.customer
SET email = 'an.nguyen.updated@test.com'
WHERE email = 'an.nguyen@test.com';

SELECT customer_id, first_name, email FROM dbo.customer
WHERE first_name = 'An' AND last_name = 'Nguyen';
GO

-- ============================================================
-- *** HÀNH ĐỘNG: CHẠY SSIS PACKAGE ***
-- Sau khi thêm dữ liệu xong, chạy toàn bộ SSIS pipeline
-- Control Flow từ đầu đến cuối
-- ============================================================

-- ============================================================
-- BƯỚC CUỐI: KIỂM TRA DW SAU KHI CHẠY SSIS
-- Chạy phần này SAU KHI SSIS pipeline hoàn thành
-- ============================================================
USE Sakila_DW;
GO

PRINT '=== KIỂM TRA SAU KHI CHẠY SSIS ===';

-- 1. Số dòng tăng lên chưa
PRINT '--- Số dòng sau khi ETL ---';
SELECT
    'Dim_Customer'  AS bang, COUNT(*) AS so_dong FROM dw.Dim_Customer WHERE is_current = 1
UNION ALL SELECT 'Fact_Sale',   COUNT(*) FROM dw.Fact_Sale
UNION ALL SELECT 'Dim_Product', COUNT(*) FROM dw.Dim_Product WHERE is_current = 1;
GO

-- 2. Khách hàng mới đã vào DW chưa
PRINT '--- Khách hàng mới trong DW ---';
SELECT
    customer_key,
    customer_id,
    full_name,
    email,
    customer_class,
    effective_date,
    is_current
FROM dw.Dim_Customer
WHERE email IN (
    'an.nguyen@test.com',
    'an.nguyen.updated@test.com',  -- version mới sau SCD2
    'binh.tran@test.com',
    'chi.le@test.com'
)
ORDER BY customer_id, effective_date;
GO

-- 3. SCD2 có lưu lịch sử email thay đổi không
PRINT '--- Lịch sử SCD2 của An Nguyen ---';
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
WHERE full_name = 'An Nguyen'
ORDER BY effective_date;
GO

-- 4. Giao dịch mới đã vào Fact_Sale chưa
PRINT '--- Giao dịch mới trong Fact_Sale ---';
SELECT
    fs.sale_key,
    fs.rental_id,
    dc.full_name        AS khach_hang,
    dc.email,
    fs.amount,
    dd.date            AS ngay_thue,
    CASE WHEN fs.is_returned = 0 THEN 'Chưa trả'
         WHEN fs.is_late = 1     THEN 'Trả muộn'
         ELSE 'Đúng hạn'
    END                AS trang_thai_tra,
    fs.late_days
FROM dw.Fact_Sale fs
JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key AND dc.is_current = 1
JOIN dw.Dim_Date     dd ON fs.rental_date_key = dd.date_key
WHERE dc.email IN (
    'an.nguyen.updated@test.com',
    'binh.tran@test.com',
    'chi.le@test.com'
)
ORDER BY fs.sale_key;
GO

-- 5. Tổng kết
PRINT '=== TỔNG KẾT ===';
DECLARE @new_cust INT = (
    SELECT COUNT(*) FROM dw.Dim_Customer
    WHERE email IN ('an.nguyen.updated@test.com','binh.tran@test.com','chi.le@test.com')
    AND is_current = 1
);
DECLARE @scd2_hist INT = (
    SELECT COUNT(*) FROM dw.Dim_Customer
    WHERE full_name = 'An Nguyen'
);
DECLARE @new_fact INT = (
    SELECT COUNT(*) FROM dw.Fact_Sale fs
    JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
    WHERE dc.email IN ('an.nguyen.updated@test.com','binh.tran@test.com','chi.le@test.com')
);

PRINT 'KB1 - Khách hàng mới trong DW: ' + CAST(@new_cust AS VARCHAR) + '/3 ' +
      CASE WHEN @new_cust = 3 THEN '✓ ĐẠT' ELSE '✗ CHƯA ĐẠT' END;
PRINT 'KB3 - Lịch sử SCD2 An Nguyen: ' + CAST(@scd2_hist AS VARCHAR) + ' bản ghi ' +
      CASE WHEN @scd2_hist >= 2 THEN '✓ ĐẠT (có lịch sử)' ELSE '✗ CHƯA ĐẠT' END;
PRINT 'KB2 - Giao dịch mới trong Fact: ' + CAST(@new_fact AS VARCHAR) + '/3 ' +
      CASE WHEN @new_fact = 3 THEN '✓ ĐẠT' ELSE '✗ CHƯA ĐẠT' END;
GO

-- ============================================================
-- DỌN DẸP (chạy sau khi đã chụp xong minh chứng)
-- ============================================================
/*
-- Xóa dữ liệu test khỏi nguồn
USE Sakila_Sales;
DELETE FROM dbo.payment WHERE customer_id IN (
    SELECT customer_id FROM Sakila_CRM.dbo.customer
    WHERE email IN ('an.nguyen.updated@test.com','binh.tran@test.com','chi.le@test.com')
);
DELETE FROM dbo.rental WHERE customer_id IN (
    SELECT customer_id FROM Sakila_CRM.dbo.customer
    WHERE email IN ('an.nguyen.updated@test.com','binh.tran@test.com','chi.le@test.com')
);

USE Sakila_CRM;
DELETE FROM dbo.customer
WHERE email IN ('an.nguyen.updated@test.com','binh.tran@test.com','chi.le@test.com');

-- Ghi chú: Dữ liệu trong DW vẫn giữ nguyên
-- Đây là expected behavior — DW lưu lịch sử, không xóa theo nguồn
*/
