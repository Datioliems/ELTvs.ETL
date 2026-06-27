-- ============================================================
-- Fix: Đổi effective_date, expiry_date sang DATETIME
-- để SCD Wizard nhận ra trong dropdown
-- Áp dụng cho: Dim_Geography_Store, Dim_Staff,
--              Dim_Customer, Dim_Product
-- ============================================================
USE Sakila_DW;
GO

-- ============================================================
-- Dim_Geography_Store
-- ============================================================
-- Xóa DEFAULT constraint của effective_date
DECLARE @df NVARCHAR(200) = (
    SELECT name FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dw.Dim_Geography_Store')
    AND   col_name(parent_object_id, parent_column_id) = 'effective_date'
);
IF @df IS NOT NULL EXEC('ALTER TABLE dw.Dim_Geography_Store DROP CONSTRAINT ' + @df);

-- Đổi kiểu
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN expiry_date    DATETIME NULL;

-- Tạo lại DEFAULT
ALTER TABLE dw.Dim_Geography_Store ADD DEFAULT GETDATE() FOR effective_date;
PRINT '+ Dim_Geography_Store: effective_date, expiry_date → DATETIME OK';
GO

-- ============================================================
-- Dim_Staff
-- ============================================================
DECLARE @df NVARCHAR(200) = (
    SELECT name FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dw.Dim_Staff')
    AND   col_name(parent_object_id, parent_column_id) = 'effective_date'
);
IF @df IS NOT NULL EXEC('ALTER TABLE dw.Dim_Staff DROP CONSTRAINT ' + @df);

ALTER TABLE dw.Dim_Staff ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN expiry_date    DATETIME NULL;

ALTER TABLE dw.Dim_Staff ADD DEFAULT GETDATE() FOR effective_date;
PRINT '+ Dim_Staff: effective_date, expiry_date → DATETIME OK';
GO

-- ============================================================
-- Dim_Customer
-- ============================================================
DECLARE @df NVARCHAR(200) = (
    SELECT name FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dw.Dim_Customer')
    AND   col_name(parent_object_id, parent_column_id) = 'effective_date'
);
IF @df IS NOT NULL EXEC('ALTER TABLE dw.Dim_Customer DROP CONSTRAINT ' + @df);

ALTER TABLE dw.Dim_Customer ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Customer ALTER COLUMN expiry_date    DATETIME NULL;

ALTER TABLE dw.Dim_Customer ADD DEFAULT GETDATE() FOR effective_date;
PRINT '+ Dim_Customer: effective_date, expiry_date → DATETIME OK';
GO

-- ============================================================
-- Dim_Product
-- ============================================================
DECLARE @df NVARCHAR(200) = (
    SELECT name FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dw.Dim_Product')
    AND   col_name(parent_object_id, parent_column_id) = 'effective_date'
);
IF @df IS NOT NULL EXEC('ALTER TABLE dw.Dim_Product DROP CONSTRAINT ' + @df);

ALTER TABLE dw.Dim_Product ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Product ALTER COLUMN expiry_date    DATETIME NULL;

ALTER TABLE dw.Dim_Product ADD DEFAULT GETDATE() FOR effective_date;
PRINT '+ Dim_Product: effective_date, expiry_date → DATETIME OK';
GO

-- Kiểm tra kết quả
SELECT
    t.name          AS bang,
    c.name          AS cot,
    tp.name         AS kieu_du_lieu
FROM sys.columns c
JOIN sys.tables  t  ON c.object_id  = t.object_id
JOIN sys.schemas s  ON t.schema_id  = s.schema_id
JOIN sys.types   tp ON c.user_type_id = tp.user_type_id
WHERE s.name = 'dw'
AND   c.name IN ('effective_date','expiry_date')
ORDER BY t.name;
GO
