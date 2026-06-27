-- ============================================================
-- FILE: SQLServer_Phan_He_OLTP.sql
-- MỤC ĐÍCH: Tạo 4 database phân hệ trên SQL Server từ Sakila gốc
-- CHẠY TRÊN: SSMS (kết nối vào SQL Server)
-- YÊU CẦU: Database sakila (SQL Server port) phải tồn tại
-- ============================================================

-- ============================================================
-- PHÂN HỆ 1: Sakila_Sales
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_Sales')
    CREATE DATABASE Sakila_Sales;
GO

USE Sakila_Sales;
GO

IF OBJECT_ID('dbo.rental',  'U') IS NOT NULL DROP TABLE dbo.rental;
IF OBJECT_ID('dbo.payment', 'U') IS NOT NULL DROP TABLE dbo.payment;
GO

SELECT * INTO dbo.rental  FROM sakila.dbo.rental;
SELECT * INTO dbo.payment FROM sakila.dbo.payment;

ALTER TABLE dbo.rental  ADD CONSTRAINT PK_rental  PRIMARY KEY (rental_id);
ALTER TABLE dbo.payment ADD CONSTRAINT PK_payment PRIMARY KEY (payment_id);

CREATE INDEX IX_rental_date      ON dbo.rental  (rental_date);
CREATE INDEX IX_rental_customer  ON dbo.rental  (customer_id);
CREATE INDEX IX_payment_customer ON dbo.payment (customer_id);
CREATE INDEX IX_payment_rental   ON dbo.payment (rental_id);
GO

DECLARE @CountRental INT, @CountPayment INT;

SELECT @CountRental = COUNT(*) FROM dbo.rental;
SELECT @CountPayment = COUNT(*) FROM dbo.payment;

PRINT 'Sakila_Sales — rental:  ' + CAST(@CountRental AS VARCHAR(10)) + ' dòng';
PRINT 'Sakila_Sales — payment: ' + CAST(@CountPayment AS VARCHAR(10)) + ' dòng';
GO


-- ============================================================
-- PHÂN HỆ 2: Sakila_CRM
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_CRM')
    CREATE DATABASE Sakila_CRM;
GO

USE Sakila_CRM;
GO

IF OBJECT_ID('dbo.customer', 'U') IS NOT NULL DROP TABLE dbo.customer;
IF OBJECT_ID('dbo.address',  'U') IS NOT NULL DROP TABLE dbo.address;
IF OBJECT_ID('dbo.city',     'U') IS NOT NULL DROP TABLE dbo.city;
IF OBJECT_ID('dbo.country',  'U') IS NOT NULL DROP TABLE dbo.country;
GO

SELECT * INTO dbo.country  FROM sakila.dbo.country;
SELECT * INTO dbo.city     FROM sakila.dbo.city;
SELECT * INTO dbo.address  FROM sakila.dbo.address;
SELECT * INTO dbo.customer FROM sakila.dbo.customer;

ALTER TABLE dbo.country  ADD CONSTRAINT PK_country  PRIMARY KEY (country_id);
ALTER TABLE dbo.city     ADD CONSTRAINT PK_city     PRIMARY KEY (city_id);
ALTER TABLE dbo.address  ADD CONSTRAINT PK_address  PRIMARY KEY (address_id);
ALTER TABLE dbo.customer ADD CONSTRAINT PK_customer PRIMARY KEY (customer_id);

CREATE INDEX IX_customer_address ON dbo.customer (address_id);
CREATE INDEX IX_city_country      ON dbo.city     (country_id);
GO

DECLARE @r INT; SELECT @r = COUNT(*) FROM dbo.customer; PRINT 'Sakila_CRM — customer: ' + CAST(@r AS VARCHAR) + ' dòng';
DECLARE @r2 INT; SELECT @r2 = COUNT(*) FROM dbo.address;  PRINT 'Sakila_CRM — address:  ' + CAST(@r2 AS VARCHAR) + ' dòng';
GO


-- ============================================================
-- PHÂN HỆ 3: Sakila_Inventory
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_Inventory')
    CREATE DATABASE Sakila_Inventory;
GO

USE Sakila_Inventory;
GO

IF OBJECT_ID('dbo.film_category', 'U') IS NOT NULL DROP TABLE dbo.film_category;
IF OBJECT_ID('dbo.inventory',     'U') IS NOT NULL DROP TABLE dbo.inventory;
IF OBJECT_ID('dbo.film',          'U') IS NOT NULL DROP TABLE dbo.film;
IF OBJECT_ID('dbo.category',      'U') IS NOT NULL DROP TABLE dbo.category;
IF OBJECT_ID('dbo.language',      'U') IS NOT NULL DROP TABLE dbo.language;
GO

SELECT * INTO dbo.language      FROM sakila.dbo.language;
SELECT * INTO dbo.film          FROM sakila.dbo.film;
SELECT * INTO dbo.category      FROM sakila.dbo.category;
SELECT * INTO dbo.film_category FROM sakila.dbo.film_category;
SELECT * INTO dbo.inventory     FROM sakila.dbo.inventory;

ALTER TABLE dbo.language  ADD CONSTRAINT PK_language  PRIMARY KEY (language_id);
ALTER TABLE dbo.film      ADD CONSTRAINT PK_film      PRIMARY KEY (film_id);
ALTER TABLE dbo.category  ADD CONSTRAINT PK_category  PRIMARY KEY (category_id);
ALTER TABLE dbo.inventory ADD CONSTRAINT PK_inventory PRIMARY KEY (inventory_id);

CREATE INDEX IX_film_language    ON dbo.film      (language_id);
CREATE INDEX IX_inventory_film   ON dbo.inventory (film_id);
CREATE INDEX IX_inventory_store  ON dbo.inventory (store_id);
GO

DECLARE @r INT; SELECT @r = COUNT(*) FROM dbo.film;      PRINT 'Sakila_Inventory — film:      ' + CAST(@r AS VARCHAR) + ' dòng';
DECLARE @r2 INT; SELECT @r2 = COUNT(*) FROM dbo.inventory; PRINT 'Sakila_Inventory — inventory: ' + CAST(@r2 AS VARCHAR) + ' dòng';
GO


-- ============================================================
-- PHÂN HỆ 4: Sakila_HRM
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_HRM')
    CREATE DATABASE Sakila_HRM;
GO

USE Sakila_HRM;
GO

IF OBJECT_ID('dbo.staff',   'U') IS NOT NULL DROP TABLE dbo.staff;
IF OBJECT_ID('dbo.store',   'U') IS NOT NULL DROP TABLE dbo.store;
IF OBJECT_ID('dbo.address', 'U') IS NOT NULL DROP TABLE dbo.address;
IF OBJECT_ID('dbo.city',    'U') IS NOT NULL DROP TABLE dbo.city;
IF OBJECT_ID('dbo.country', 'U') IS NOT NULL DROP TABLE dbo.country;
GO

-- Chỉ lấy country/city/address liên quan đến staff và store
SELECT DISTINCT co.*
INTO dbo.country
FROM sakila.dbo.country co
INNER JOIN sakila.dbo.city ci    ON co.country_id = ci.country_id
INNER JOIN sakila.dbo.address a  ON ci.city_id    = a.city_id
WHERE a.address_id IN (
    SELECT address_id FROM sakila.dbo.staff
    UNION
    SELECT address_id FROM sakila.dbo.store
);

SELECT DISTINCT ci.*
INTO dbo.city
FROM sakila.dbo.city ci
INNER JOIN sakila.dbo.address a ON ci.city_id = a.city_id
WHERE a.address_id IN (
    SELECT address_id FROM sakila.dbo.staff
    UNION
    SELECT address_id FROM sakila.dbo.store
);

SELECT DISTINCT a.*
INTO dbo.address
FROM sakila.dbo.address a
WHERE a.address_id IN (
    SELECT address_id FROM sakila.dbo.staff
    UNION
    SELECT address_id FROM sakila.dbo.store
);

SELECT * INTO dbo.store FROM sakila.dbo.store;
SELECT * INTO dbo.staff FROM sakila.dbo.staff;

ALTER TABLE dbo.country ADD CONSTRAINT PK_country PRIMARY KEY (country_id);
ALTER TABLE dbo.city    ADD CONSTRAINT PK_city    PRIMARY KEY (city_id);
ALTER TABLE dbo.address ADD CONSTRAINT PK_address PRIMARY KEY (address_id);
ALTER TABLE dbo.store   ADD CONSTRAINT PK_store   PRIMARY KEY (store_id);
ALTER TABLE dbo.staff   ADD CONSTRAINT PK_staff   PRIMARY KEY (staff_id);
GO

DECLARE @r INT; SELECT @r = COUNT(*) FROM dbo.staff; PRINT 'Sakila_HRM — staff: ' + CAST(@r AS VARCHAR) + ' dòng';
DECLARE @r2 INT; SELECT @r2 = COUNT(*) FROM dbo.store; PRINT 'Sakila_HRM — store: ' + CAST(@r2 AS VARCHAR) + ' dòng';
GO


-- ============================================================
-- KIỂM TRA TỔNG QUAN 4 PHÂN HỆ
-- ============================================================
USE master;
GO

SELECT 'Sakila_Sales'     AS phan_he, 'rental'       AS bang, COUNT(*) AS so_dong FROM Sakila_Sales.dbo.rental
UNION ALL SELECT 'Sakila_Sales',     'payment',      COUNT(*) FROM Sakila_Sales.dbo.payment
UNION ALL SELECT 'Sakila_CRM',       'customer',     COUNT(*) FROM Sakila_CRM.dbo.customer
UNION ALL SELECT 'Sakila_CRM',       'address',      COUNT(*) FROM Sakila_CRM.dbo.address
UNION ALL SELECT 'Sakila_CRM',       'city',         COUNT(*) FROM Sakila_CRM.dbo.city
UNION ALL SELECT 'Sakila_CRM',       'country',      COUNT(*) FROM Sakila_CRM.dbo.country
UNION ALL SELECT 'Sakila_Inventory', 'film',         COUNT(*) FROM Sakila_Inventory.dbo.film
UNION ALL SELECT 'Sakila_Inventory', 'category',     COUNT(*) FROM Sakila_Inventory.dbo.category
UNION ALL SELECT 'Sakila_Inventory', 'inventory',    COUNT(*) FROM Sakila_Inventory.dbo.inventory
UNION ALL SELECT 'Sakila_HRM',       'staff',        COUNT(*) FROM Sakila_HRM.dbo.staff
UNION ALL SELECT 'Sakila_HRM',       'store',        COUNT(*) FROM Sakila_HRM.dbo.store
ORDER BY phan_he, bang;
GO
