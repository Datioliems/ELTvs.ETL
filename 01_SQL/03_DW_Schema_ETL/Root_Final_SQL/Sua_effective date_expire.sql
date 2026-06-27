USE Sakila_DW;

-- Dim_Geography_Store
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Geography_Store ALTER COLUMN expiry_date    DATETIME NULL;

-- Dim_Staff (nếu cũng dùng SCD Wizard)
ALTER TABLE dw.Dim_Staff ALTER COLUMN effective_date DATETIME NOT NULL;
ALTER TABLE dw.Dim_Staff ALTER COLUMN expiry_date    DATETIME NULL;