-- ============================================================
-- FILE: 01_Create_DW_Schema.sql
-- MỤC ĐÍCH: Tạo database kho dữ liệu Sakila_DW và tất cả các bảng
--           Dim + Fact theo thiết kế Star Schema (Nhóm 9)
-- DATABASE ĐÍCH: SQL Server (Sakila_DW)
-- DATABASE NGUỒN: sakila (SQL Server port của Sakila MySQL)
-- ============================================================

-- -------------------------------------------------------
-- BƯỚC 0: Tạo database nếu chưa có
-- -------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Sakila_DW')
BEGIN
    CREATE DATABASE Sakila_DW;
    PRINT 'Đã tạo database Sakila_DW';
END
GO

USE Sakila_DW;
GO

-- -------------------------------------------------------
-- BƯỚC 1: Tạo schema DW
-- -------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw')
BEGIN
    EXEC('CREATE SCHEMA dw');
    PRINT 'Đã tạo schema dw';
END
GO

-- ============================================================
-- BẢNG: dw.Dim_Date
-- NGUỒN: Sinh tự động bằng script SQL
-- SCD: Type 0 (không thay đổi)
-- ============================================================
IF OBJECT_ID('dw.Dim_Date', 'U') IS NOT NULL DROP TABLE dw.Dim_Date;
GO

CREATE TABLE dw.Dim_Date (
    date_key        INT             NOT NULL,   -- Surrogate Key (YYYYMMDD)
    date            DATE            NOT NULL,   -- Ngày đầy đủ
    day_of_week     TINYINT         NOT NULL,   -- 1=Sunday ... 7=Saturday
    day_name        VARCHAR(10)     NOT NULL,   -- 'Monday', 'Tuesday'...
    day_of_month    TINYINT         NOT NULL,   -- 1-31
    day_of_year     SMALLINT        NOT NULL,   -- 1-366
    week_of_year    TINYINT         NOT NULL,   -- 1-52
    month_of_year   TINYINT         NOT NULL,   -- 1-12
    month_name      VARCHAR(10)     NOT NULL,   -- 'January'...
    quarter_of_year TINYINT         NOT NULL,   -- 1-4
    year            SMALLINT        NOT NULL,
    is_weekend      BIT             NOT NULL DEFAULT 0,
    is_special_day  BIT             NOT NULL DEFAULT 0,
    special_day     VARCHAR(100)    NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY (date_key)
);
GO

-- Thêm dòng đặc biệt cho return_date_key = -1 (chưa trả đĩa)
INSERT INTO dw.Dim_Date (
    date_key, date, day_of_week, day_name, day_of_month,
    day_of_year, week_of_year, month_of_year, month_name,
    quarter_of_year, year, is_weekend, is_special_day, special_day
)
VALUES (-1, '1900-01-01', 0, 'Unknown', 0, 0, 0, 0,
        'Unknown', 0, 0, 0, 0, 'Chưa trả đĩa');
GO

-- ============================================================
-- BẢNG: dw.Dim_Product
-- NGUỒN: sakila.film, sakila.category, sakila.film_category, sakila.inventory
-- SCD: Type 2
-- ============================================================
IF OBJECT_ID('dw.Dim_Product', 'U') IS NOT NULL DROP TABLE dw.Dim_Product;
GO

CREATE TABLE dw.Dim_Product (
    product_key         INT             NOT NULL IDENTITY(1001,1),
    film_id             INT             NOT NULL,       -- Natural Key từ Sakila
    title               VARCHAR(255)    NOT NULL,
    description         TEXT            NULL,
    release_year        SMALLINT        NULL,
    language_id         TINYINT         NULL,
    language_name       VARCHAR(20)     NULL,           -- Denormalized
    rental_duration     TINYINT         NULL,
    rental_rate         DECIMAL(4,2)    NULL,
    length              SMALLINT        NULL,
    replacement_cost    DECIMAL(5,2)    NULL,
    rating              VARCHAR(10)     NULL,
    category_id         TINYINT         NULL,
    category_name       VARCHAR(25)     NULL,           -- Denormalized
    inventory_count     INT             NULL DEFAULT 0,
    -- SCD Type 2 fields
    effective_date      DATE            NOT NULL,
    expiry_date         DATE            NULL,
    is_current          BIT             NOT NULL DEFAULT 1,
    created_date        DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_date        DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system       VARCHAR(20)     NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Product PRIMARY KEY (product_key)
);

CREATE INDEX IX_Dim_Product_FilmId  ON dw.Dim_Product (film_id);
CREATE INDEX IX_Dim_Product_Current ON dw.Dim_Product (film_id, is_current);
GO

-- ============================================================
-- BẢNG: dw.Dim_Staff
-- NGUỒN: sakila.staff, sakila.store, sakila.address, sakila.city, sakila.country
-- SCD: Type 2
-- ============================================================
IF OBJECT_ID('dw.Dim_Staff', 'U') IS NOT NULL DROP TABLE dw.Dim_Staff;
GO

CREATE TABLE dw.Dim_Staff (
    staff_key       INT             NOT NULL IDENTITY(1001,1),
    staff_id        TINYINT         NOT NULL,       -- Natural Key từ Sakila
    first_name      VARCHAR(45)     NOT NULL,
    last_name       VARCHAR(45)     NOT NULL,
    full_name       VARCHAR(91)     NOT NULL,       -- Derived: first + last
    email           VARCHAR(50)     NULL,           -- SCD Type 1
    username        VARCHAR(16)     NULL,
    active          BIT             NOT NULL DEFAULT 1,
    store_id        TINYINT         NULL,
    store_name      VARCHAR(50)     NULL,           -- Denormalized
    address         VARCHAR(50)     NULL,           -- Denormalized
    district        VARCHAR(20)     NULL,           -- Denormalized
    city_name       VARCHAR(50)     NULL,           -- Denormalized
    country_name    VARCHAR(50)     NULL,           -- Denormalized
    -- SCD Type 2 fields
    effective_date  DATE            NOT NULL,
    expiry_date     DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 1,
    created_date    DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_date    DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system   VARCHAR(20)     NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Staff PRIMARY KEY (staff_key)
);

CREATE INDEX IX_Dim_Staff_StaffId  ON dw.Dim_Staff (staff_id);
CREATE INDEX IX_Dim_Staff_Current  ON dw.Dim_Staff (staff_id, is_current);
GO

-- ============================================================
-- BẢNG: dw.Dim_Customer
-- NGUỒN: sakila.customer, sakila.address, sakila.city, sakila.country
-- SCD: Type 2
-- ============================================================
IF OBJECT_ID('dw.Dim_Customer', 'U') IS NOT NULL DROP TABLE dw.Dim_Customer;
GO

CREATE TABLE dw.Dim_Customer (
    customer_key    INT             NOT NULL IDENTITY(1001,1),
    customer_id     SMALLINT        NOT NULL,       -- Natural Key từ Sakila
    first_name      VARCHAR(45)     NOT NULL,
    last_name       VARCHAR(45)     NOT NULL,
    full_name       VARCHAR(91)     NOT NULL,       -- Derived
    email           VARCHAR(50)     NULL,
    address         VARCHAR(50)     NULL,           -- Denormalized
    city            VARCHAR(50)     NULL,           -- Denormalized
    country         VARCHAR(50)     NULL,           -- Denormalized
    customer_class  VARCHAR(10)     NULL,           -- Derived: Vàng/Bạc/Đồng
    -- SCD Type 2 fields
    effective_date  DATE            NOT NULL,
    expiry_date     DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 1,
    create_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    update_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system   VARCHAR(20)     NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Customer PRIMARY KEY (customer_key)
);

CREATE INDEX IX_Dim_Customer_CustId  ON dw.Dim_Customer (customer_id);
CREATE INDEX IX_Dim_Customer_Current ON dw.Dim_Customer (customer_id, is_current);
GO

-- ============================================================
-- BẢNG: dw.Dim_Geography_Store
-- NGUỒN: sakila.store, sakila.address, sakila.city, sakila.country
-- SCD: Type 2
-- ============================================================
IF OBJECT_ID('dw.Dim_Geography_Store', 'U') IS NOT NULL DROP TABLE dw.Dim_Geography_Store;
GO

CREATE TABLE dw.Dim_Geography_Store (
    store_key       INT             NOT NULL IDENTITY(1001,1),
    store_id        TINYINT         NOT NULL,       -- Natural Key từ Sakila
    address         VARCHAR(50)     NULL,           -- Denormalized
    district        VARCHAR(20)     NULL,
    postal_code     VARCHAR(10)     NULL,
    phone           VARCHAR(20)     NULL,
    city_id         SMALLINT        NULL,
    city            VARCHAR(50)     NULL,           -- Denormalized
    country_id      SMALLINT        NULL,
    country         VARCHAR(50)     NULL,           -- Denormalized
    -- SCD Type 2 fields
    effective_date  DATE            NOT NULL,
    expiry_date     DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 1,
    create_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    update_date     DATETIME        NOT NULL DEFAULT GETDATE(),
    source_system   VARCHAR(20)     NOT NULL DEFAULT 'SAKILA',
    CONSTRAINT PK_Dim_Geography_Store PRIMARY KEY (store_key)
);

CREATE INDEX IX_Dim_GeoStore_StoreId  ON dw.Dim_Geography_Store (store_id);
CREATE INDEX IX_Dim_GeoStore_Current  ON dw.Dim_Geography_Store (store_id, is_current);
GO

-- ============================================================
-- BẢNG: dw.Fact_Sale
-- NGUỒN: sakila.rental, sakila.payment + Dim lookups
-- Kiểu: Transaction Fact Table
-- ============================================================
IF OBJECT_ID('dw.Fact_Sale', 'U') IS NOT NULL DROP TABLE dw.Fact_Sale;
GO

CREATE TABLE dw.Fact_Sale (
    -- Surrogate Key
    sale_key                    INT             NOT NULL IDENTITY(1,1),
    -- Degenerate Dimension
    rental_id                   INT             NOT NULL,
    -- Foreign Keys -> Dim_Date (Role-Playing)
    rental_date_key             INT             NOT NULL,   -- FK -> Dim_Date
    return_date_key             INT             NOT NULL,   -- FK -> Dim_Date (-1 nếu chưa trả)
    payment_date_key            INT             NOT NULL,   -- FK -> Dim_Date
    -- Foreign Keys -> Bảng chiều
    customer_key                INT             NOT NULL,   -- FK -> Dim_Customer
    product_key                 INT             NOT NULL,   -- FK -> Dim_Product
    store_key                   INT             NOT NULL,   -- FK -> Dim_Geography_Store
    staff_key                   INT             NOT NULL,   -- FK -> Dim_Staff
    -- Measures
    amount                      DECIMAL(5,2)    NOT NULL DEFAULT 0,     -- Fully Additive
    rental_duration_expected    TINYINT         NULL,                   -- Fully Additive
    rental_duration_actual      INT             NULL,                   -- Semi-Additive
    late_days                   INT             NOT NULL DEFAULT 0,     -- Semi-Additive
    is_late                     TINYINT         NOT NULL DEFAULT 0,     -- Non-Additive flag
    is_returned                 TINYINT         NOT NULL DEFAULT 0,     -- Non-Additive flag
    replacement_cost            DECIMAL(5,2)    NULL,                   -- Fully Additive (when is_returned=0)
    CONSTRAINT PK_Fact_Sale PRIMARY KEY (sale_key),
    CONSTRAINT FK_FS_RentalDate  FOREIGN KEY (rental_date_key)  REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_ReturnDate  FOREIGN KEY (return_date_key)  REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_PayDate     FOREIGN KEY (payment_date_key) REFERENCES dw.Dim_Date(date_key),
    CONSTRAINT FK_FS_Customer    FOREIGN KEY (customer_key)     REFERENCES dw.Dim_Customer(customer_key),
    CONSTRAINT FK_FS_Product     FOREIGN KEY (product_key)      REFERENCES dw.Dim_Product(product_key),
    CONSTRAINT FK_FS_Store       FOREIGN KEY (store_key)        REFERENCES dw.Dim_Geography_Store(store_key),
    CONSTRAINT FK_FS_Staff       FOREIGN KEY (staff_key)        REFERENCES dw.Dim_Staff(staff_key)
);

CREATE INDEX IX_FS_RentalDate  ON dw.Fact_Sale (rental_date_key);
CREATE INDEX IX_FS_ReturnDate  ON dw.Fact_Sale (return_date_key);
CREATE INDEX IX_FS_Customer    ON dw.Fact_Sale (customer_key);
CREATE INDEX IX_FS_Product     ON dw.Fact_Sale (product_key);
CREATE INDEX IX_FS_Store       ON dw.Fact_Sale (store_key);
CREATE INDEX IX_FS_Staff       ON dw.Fact_Sale (staff_key);
GO

-- ============================================================
-- BẢNG AGGREGATE FACT (Tổng hợp)
-- ============================================================

-- Fact_Sale_byCustomer
IF OBJECT_ID('dw.Fact_Sale_byCustomer','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byCustomer;
CREATE TABLE dw.Fact_Sale_byCustomer (
    agg_key         INT         NOT NULL IDENTITY(1,1),
    date_key        INT         NOT NULL,
    customer_key    INT         NOT NULL,
    store_key       INT         NOT NULL,
    staff_key       INT         NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count    INT         NOT NULL DEFAULT 0,
    late_count      INT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByCustomer PRIMARY KEY (agg_key)
);
GO

-- Fact_Sale_byProduct
IF OBJECT_ID('dw.Fact_Sale_byProduct','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byProduct;
CREATE TABLE dw.Fact_Sale_byProduct (
    agg_key         INT         NOT NULL IDENTITY(1,1),
    date_key        INT         NOT NULL,
    product_key     INT         NOT NULL,
    store_key       INT         NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count    INT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByProduct PRIMARY KEY (agg_key)
);
GO

-- Fact_Sale_byStore
IF OBJECT_ID('dw.Fact_Sale_byStore','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byStore;
CREATE TABLE dw.Fact_Sale_byStore (
    agg_key         INT         NOT NULL IDENTITY(1,1),
    date_key        INT         NOT NULL,
    store_key       INT         NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count    INT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByStore PRIMARY KEY (agg_key)
);
GO

-- Fact_Sale_byStaff
IF OBJECT_ID('dw.Fact_Sale_byStaff','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byStaff;
CREATE TABLE dw.Fact_Sale_byStaff (
    agg_key         INT         NOT NULL IDENTITY(1,1),
    date_key        INT         NOT NULL,
    store_key       INT         NOT NULL,
    staff_key       INT         NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count    INT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByStaff PRIMARY KEY (agg_key)
);
GO

-- Fact_Sale_byDate
IF OBJECT_ID('dw.Fact_Sale_byDate','U') IS NOT NULL DROP TABLE dw.Fact_Sale_byDate;
CREATE TABLE dw.Fact_Sale_byDate (
    agg_key         INT         NOT NULL IDENTITY(1,1),
    date_key        INT         NOT NULL,
    customer_key    INT         NOT NULL,
    store_key       INT         NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL DEFAULT 0,
    rental_count    INT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_FSByDate PRIMARY KEY (agg_key)
);
GO

PRINT '=== Tạo schema thành công: Sakila_DW ===';
GO
