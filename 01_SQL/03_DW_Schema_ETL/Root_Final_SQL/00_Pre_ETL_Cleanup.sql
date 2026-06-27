-- ============================================================
-- FILE: 00_Pre_ETL_Cleanup.sql
-- MỤC ĐÍCH: Dọn dẹp toàn bộ DW trước khi chạy ETL
--           Đặt trong Execute SQL Task ĐẦU TIÊN trong Control Flow
--           Chạy mỗi lần trước toàn bộ pipeline
-- CONNECTION: CM_SS_DW
-- ============================================================
USE Sakila_DW;
GO

PRINT 'Bắt đầu dọn dẹp DW: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- ============================================================
-- BƯỚC 1: Xóa Aggregate Fact Tables trước
-- (không có FK trỏ vào đây nên TRUNCATE được ngay)
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byCustomer;
TRUNCATE TABLE dw.Fact_Sale_byProduct;
TRUNCATE TABLE dw.Fact_Sale_byStore;
TRUNCATE TABLE dw.Fact_Sale_byStaff;
TRUNCATE TABLE dw.Fact_Sale_byDate;
PRINT '✓ Aggregate tables cleared';

-- ============================================================
-- BƯỚC 2: Xóa Fact_Sale
-- (FK trỏ vào Dim — phải xóa trước Dim)
-- ============================================================
DELETE FROM dw.Fact_Sale;
PRINT '✓ Fact_Sale cleared: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- ============================================================
-- BƯỚC 3: Xóa các Dim (trừ Dim_Date)
-- Xóa toàn bộ để load lại sạch từ nguồn
-- RESEED IDENTITY về 1001 để surrogate key bắt đầu lại
-- ============================================================
DELETE FROM dw.Dim_Customer;
DBCC CHECKIDENT ('dw.Dim_Customer', RESEED, 1000);
PRINT '✓ Dim_Customer cleared';

DELETE FROM dw.Dim_Product;
DBCC CHECKIDENT ('dw.Dim_Product', RESEED, 1000);
PRINT '✓ Dim_Product cleared';

DELETE FROM dw.Dim_Staff;
DBCC CHECKIDENT ('dw.Dim_Staff', RESEED, 1000);
PRINT '✓ Dim_Staff cleared';

DELETE FROM dw.Dim_Geography_Store;
DBCC CHECKIDENT ('dw.Dim_Geography_Store', RESEED, 1000);
PRINT '✓ Dim_Geography_Store cleared';

-- ============================================================
-- BƯỚC 4: Xóa Dim_Date (trừ dòng -1)
-- Dòng -1 giữ lại vì Load_Dim_Date chỉ DELETE WHERE date_key > 0
-- ============================================================
DELETE FROM dw.Dim_Date WHERE date_key > 0;
PRINT '✓ Dim_Date cleared (giữ dòng -1)';

-- ============================================================
-- Kiểm tra nhanh
-- ============================================================
PRINT '';
PRINT '=== Trạng thái sau cleanup ===';
SELECT
    'Fact_Sale'             AS bang, COUNT(*) AS so_dong FROM dw.Fact_Sale
UNION ALL SELECT 'Dim_Customer',     COUNT(*) FROM dw.Dim_Customer
UNION ALL SELECT 'Dim_Product',      COUNT(*) FROM dw.Dim_Product
UNION ALL SELECT 'Dim_Staff',        COUNT(*) FROM dw.Dim_Staff
UNION ALL SELECT 'Dim_Geography_Store', COUNT(*) FROM dw.Dim_Geography_Store
UNION ALL SELECT 'Dim_Date (chỉ -1)',COUNT(*) FROM dw.Dim_Date;

PRINT 'Cleanup hoàn thành: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Sẵn sàng chạy ETL pipeline...';
GO
