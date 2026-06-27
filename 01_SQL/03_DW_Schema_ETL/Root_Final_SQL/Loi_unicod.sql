USE Sakila_DW;
GO

-- ============================================================
-- 1. CẬP NHẬT BẢNG: dw.Dim_Product
-- ============================================================
ALTER TABLE dw.Dim_Product ALTER COLUMN title NVARCHAR(255) NOT NULL;
ALTER TABLE dw.Dim_Product ALTER COLUMN language_name NVARCHAR(20) NULL;
ALTER TABLE dw.Dim_Product ALTER COLUMN rating NVARCHAR(10) NULL;
ALTER TABLE dw.Dim_Product ALTER COLUMN category_name NVARCHAR(25) NULL;
-- Lưu ý: Cột [description] đang là TEXT (Non-Unicode), nên đổi sang NVARCHAR(MAX) để hỗ trợ Unicode dung lượng lớn
ALTER TABLE dw.Dim_Product ALTER COLUMN description NVARCHAR(MAX) NULL; 
GO

-- ============================================================
-- 2. CẬP NHẬT BẢNG: dw.Dim_Staff
-- ============================================================
ALTER TABLE dw.Dim_Staff ALTER COLUMN first_name NVARCHAR(45) NOT NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN last_name NVARCHAR(45) NOT NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN full_name NVARCHAR(91) NOT NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN email NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN username NVARCHAR(16) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN store_name NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN address NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN district NVARCHAR(20) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN city_name NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN country_name NVARCHAR(50) NULL;
GO

-- ============================================================
-- 3. CẬP NHẬT BẢNG: dw.Dim_Geography_Store
-- ============================================================
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN address NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN district NVARCHAR(20) NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN postal_code NVARCHAR(10) NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN phone NVARCHAR(20) NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN city NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN country NVARCHAR(50) NULL;
GO


ALTER TABLE dw.Dim_Customer ALTER COLUMN first_name NVARCHAR(45) NOT NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN last_name NVARCHAR(45) NOT NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN full_name NVARCHAR(91) NOT NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN email NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN address NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN city NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN country NVARCHAR(50) NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN customer_class NVARCHAR(10) NULL;
GO