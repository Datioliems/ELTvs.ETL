-- ============================================================
-- FILE: 01_Create_DW_Schema_Final.sql
-- Fix: DROP Fact trước Dim để tránh FK constraint error
-- ============================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_DW')
    CREATE DATABASE Sakila_DW;
GO
USE Sakila_DW;
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

-- ============================================================
-- BƯỚC 1: DROP tất cả theo đúng thứ tự (Fact trước, Dim sau)
-- Phải drop FK constraints trước hoặc drop Fact trước Dim
-- ============================================================

-- Drop Aggregate Fact Tables trước
IF OBJECT_ID('dw.Fact_Sale_byCustomer','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byCustomer;
IF OBJECT_ID('dw.Fact_Sale_byProduct', 'U') IS NOT NULL DROP TABLE dw.Fact_Sale_byProduct;
IF OBJECT_ID('dw.Fact_Sale_byStore',   'U') IS NOT NULL DROP TABLE dw.Fact_Sale_byStore;
IF OBJECT_ID('dw.Fact_Sale_byStaff',   'U') IS NOT NULL DROP TABLE dw.Fact_Sale_byStaff;
IF OBJECT_ID('dw.Fact_Sale_byDate',    'U') IS NOT NULL DROP TABLE dw.Fact_Sale_byDate;

-- Drop Fact_Sale (có FK trỏ vào tất cả Dim)
IF OBJECT_ID('dw.Fact_Sale','U') IS NOT NULL DROP TABLE dw.Fact_Sale;

-- Bây giờ mới DROP được Dim
IF OBJECT_ID('dw.Dim_Date',             'U') IS NOT NULL DROP TABLE dw.Dim_Date;
IF OBJECT_ID('dw.Dim_Product',          'U') IS NOT NULL DROP TABLE dw.Dim_Product;
IF OBJECT_ID('dw.Dim_Staff',            'U') IS NOT NULL DROP TABLE dw.Dim_Staff;
IF OBJECT_ID('dw.Dim_Customer',         'U') IS NOT NULL DROP TABLE dw.Dim_Customer;
IF OBJECT_ID('dw.Dim_Geography_Store',  'U') IS NOT NULL DROP TABLE dw.Dim_Geography_Store;

PRINT 'Drop tables OK';
GO

-- ============================================================
-- dw.Dim_Date
-- ============================================================
CREATE TABLE dw.Dim_Date (
    date_key        INT             NOT NULL,
    date            DATE            NOT NULL,
    day_of_week     INT             NOT NULL,
    day_name        NVARCHAR(10)    NOT NULL,
    day_of_month    INT             NOT NULL,
    day_of_year     INT             NOT NULL,
    week_of_year    INT             NOT NULL,
    month_of_year   INT             NOT NULL,
    month_name      NVARCHAR(10)    NOT NULL,
    quarter_of_year INT             NOT NULL,
    year            INT             NOT NULL,
    is_weekend      BIT             NOT NULL DEFAULT 0,
    is_special_day  BIT             NOT NULL DEFAULT 0,
    special_day     NVARCHAR(100)   NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY (date_key)
);

INSERT INTO dw.Dim_Date VALUES
    (-1,'1900-01-01',0,N'Unknown',0,0,0,0,N'Unknown',0,0,0,0,N'Chua tra dia');

PRINT '+ Dim_Date OK';
GO

-- ============================================================
-- dw.Dim_Product
-- ============================================================
CREATE TABLE dw.Dim_Product (
    product_key         INT             NOT NULL IDENTITY(1001,1),
    film_id             INT             NOT NULL,
    title               NVARCHAR(255)   NOT NULL,
    description         NVARCHAR(MAX)   NULL,
    release_year        INT             NULL,
    language_id         INT             NULL,
    language_name       NVARCHAR(20)    NULL,
    rental_duration     INT             NULL,
    rental_rate         DECIMAL(4,2)    NULL,
    length              INT             NULL,
    replacement_cost    DECIMAL(5,2)    NULL,
    rating              NVARCHAR(10)    NULL,
    category_id         INT             NULL,
    category_name       NVARCHAR(25)    NULL,
    inventory_count     INT             NULL DEFAULT 0,
    effective_date      DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expiry_date         DATE            NULL,
    is_current          BIT             NOT NULL DEFAULT 1,
    created_date        DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_date        DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system       NVARCHAR(20)    NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Product PRIMARY KEY (product_key)
);
CREATE INDEX IX_Dim_Product_Film    ON dw.Dim_Product (film_id);
CREATE INDEX IX_Dim_Product_Current ON dw.Dim_Product (film_id, is_current);

PRINT '+ Dim_Product OK';
GO

-- ============================================================
-- dw.Dim_Staff
-- ============================================================
CREATE TABLE dw.Dim_Staff (
    staff_key       INT             NOT NULL IDENTITY(1001,1),
    staff_id        INT             NOT NULL,
    first_name      NVARCHAR(45)    NOT NULL,
    last_name       NVARCHAR(45)    NOT NULL,
    full_name       NVARCHAR(91)    NOT NULL,
    email           NVARCHAR(50)    NULL,
    username        NVARCHAR(16)    NULL,
    active          BIT             NOT NULL DEFAULT 1,
    store_id        INT             NULL,
    store_name      NVARCHAR(50)    NULL,
    address         NVARCHAR(50)    NULL,
    district        NVARCHAR(20)    NULL,
    city_name       NVARCHAR(50)    NULL,
    country_name    NVARCHAR(50)    NULL,
    effective_date  DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expiry_date     DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 1,
    created_date    DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_date    DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system   NVARCHAR(20)    NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Staff PRIMARY KEY (staff_key)
);
CREATE INDEX IX_Dim_Staff_Staff   ON dw.Dim_Staff (staff_id);
CREATE INDEX IX_Dim_Staff_Current ON dw.Dim_Staff (staff_id, is_current);

PRINT '+ Dim_Staff OK';
GO

-- ============================================================
-- dw.Dim_Customer
-- ============================================================
CREATE TABLE dw.Dim_Customer (
    customer_key    INT             NOT NULL IDENTITY(1001,1),
    customer_id     INT             NOT NULL,
    first_name      NVARCHAR(45)    NOT NULL,
    last_name       NVARCHAR(45)    NOT NULL,
    full_name       NVARCHAR(91)    NOT NULL,
    email           NVARCHAR(50)    NULL,
    address         NVARCHAR(50)    NULL,
    city            NVARCHAR(50)    NULL,
    country         NVARCHAR(50)    NULL,
    customer_class  NVARCHAR(10)    NULL,
    effective_date  DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expiry_date     DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 1,
    create_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    update_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system   NVARCHAR(20)    NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Customer PRIMARY KEY (customer_key)
);
CREATE INDEX IX_Dim_Customer_Cust    ON dw.Dim_Customer (customer_id);
CREATE INDEX IX_Dim_Customer_Current ON dw.Dim_Customer (customer_id, is_current);

PRINT '+ Dim_Customer OK';
GO

-- ============================================================
-- dw.Dim_Geography_Store
-- ============================================================
CREATE TABLE dw.Dim_Geography_Store (
    store_key           INT             NOT NULL IDENTITY(1001,1),
    store_id            INT             NOT NULL,
    address             NVARCHAR(50)    NULL,
    district            NVARCHAR(20)    NULL,
    postal_code         NVARCHAR(10)    NULL,
    phone               NVARCHAR(20)    NULL,
    city_id             INT             NULL,
    city                NVARCHAR(50)    NULL,
    country_id          INT             NULL,
    country             NVARCHAR(50)    NULL,
    manager_staff_id    INT             NULL,
    effective_date      DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expiry_date         DATE            NULL,
    is_current          BIT             NOT NULL DEFAULT 1,
    create_date         DATETIME        NOT NULL DEFAULT GETDATE(),
    update_date         DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system       NVARCHAR(20)    NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Geography_Store PRIMARY KEY (store_key)
);
CREATE INDEX IX_Dim_GeoStore_Store   ON dw.Dim_Geography_Store (store_id);
CREATE INDEX IX_Dim_GeoStore_Current ON dw.Dim_Geography_Store (store_id, is_current);

PRINT '+ Dim_Geography_Store OK';
GO

-- ============================================================
-- dw.Fact_Sale
-- ============================================================
CREATE TABLE dw.Fact_Sale (
    sale_key                    INT             NOT NULL IDENTITY(1,1),
    rental_id                   INT             NOT NULL,
    rental_date_key             INT             NOT NULL,
    return_date_key             INT             NOT NULL,
    payment_date_key            INT             NOT NULL,
    customer_key                INT             NOT NULL,
    product_key                 INT             NOT NULL,
    store_key                   INT             NOT NULL,
    staff_key                   INT             NOT NULL,
    amount                      DECIMAL(5,2)    NOT NULL DEFAULT 0,
    rental_duration_expected    INT             NULL,
    rental_duration_actual      INT             NULL,
    late_days                   INT             NOT NULL DEFAULT 0,
    is_late                     BIT             NOT NULL DEFAULT 0,
    is_returned                 BIT             NOT NULL DEFAULT 0,
    replacement_cost            DECIMAL(5,2)    NULL,
    CONSTRAINT PK_Fact_Sale     PRIMARY KEY (sale_key),
    CONSTRAINT FK_FS_RentalDate FOREIGN KEY (rental_date_key)  REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_ReturnDate FOREIGN KEY (return_date_key)  REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_PayDate    FOREIGN KEY (payment_date_key) REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_Customer   FOREIGN KEY (customer_key)     REFERENCES dw.Dim_Customer(customer_key),
    CONSTRAINT FK_FS_Product    FOREIGN KEY (product_key)      REFERENCES dw.Dim_Product(product_key),
    CONSTRAINT FK_FS_Store      FOREIGN KEY (store_key)        REFERENCES dw.Dim_Geography_Store(store_key),
    CONSTRAINT FK_FS_Staff      FOREIGN KEY (staff_key)        REFERENCES dw.Dim_Staff(staff_key)
);
CREATE INDEX IX_FS_RentalDate ON dw.Fact_Sale (rental_date_key);
CREATE INDEX IX_FS_ReturnDate ON dw.Fact_Sale (return_date_key);
CREATE INDEX IX_FS_Customer   ON dw.Fact_Sale (customer_key);
CREATE INDEX IX_FS_Product    ON dw.Fact_Sale (product_key);
CREATE INDEX IX_FS_Store      ON dw.Fact_Sale (store_key);
CREATE INDEX IX_FS_Staff      ON dw.Fact_Sale (staff_key);

PRINT '+ Fact_Sale OK';
GO

-- ============================================================
-- Aggregate Fact Tables
-- ============================================================
CREATE TABLE dw.Fact_Sale_byCustomer (
    agg_key        INT           NOT NULL IDENTITY(1,1),
    date_key       INT           NOT NULL,
    customer_key   INT           NOT NULL,
    store_key      INT           NOT NULL,
    staff_key      INT           NOT NULL,
    customer_class NVARCHAR(10)  NULL,
    total_amount   DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count   INT           NOT NULL DEFAULT 0,
    late_count     INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByCustomer PRIMARY KEY (agg_key)
);
GO

CREATE TABLE dw.Fact_Sale_byProduct (
    agg_key      INT           NOT NULL IDENTITY(1,1),
    date_key     INT           NOT NULL,
    product_key  INT           NOT NULL,
    store_key    INT           NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByProduct PRIMARY KEY (agg_key)
);
GO

CREATE TABLE dw.Fact_Sale_byStore (
    agg_key      INT           NOT NULL IDENTITY(1,1),
    date_key     INT           NOT NULL,
    store_key    INT           NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByStore PRIMARY KEY (agg_key)
);
GO

CREATE TABLE dw.Fact_Sale_byStaff (
    agg_key      INT           NOT NULL IDENTITY(1,1),
    date_key     INT           NOT NULL,
    store_key    INT           NOT NULL,
    staff_key    INT           NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByStaff PRIMARY KEY (agg_key)
);
GO

CREATE TABLE dw.Fact_Sale_byDate (
    agg_key      INT           NOT NULL IDENTITY(1,1),
    date_key     INT           NOT NULL,
    customer_key INT           NOT NULL,
    store_key    INT           NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByDate PRIMARY KEY (agg_key)
);
GO

PRINT '+ Aggregate Tables OK';

-- Kiểm tra kết quả
SELECT t.name AS bang, p.rows AS so_dong
FROM sys.tables t
JOIN sys.schemas    s ON t.schema_id = s.schema_id
JOIN sys.indexes    i ON t.object_id = i.object_id AND i.index_id <= 1
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
WHERE s.name = 'dw'
ORDER BY t.name;
GO
