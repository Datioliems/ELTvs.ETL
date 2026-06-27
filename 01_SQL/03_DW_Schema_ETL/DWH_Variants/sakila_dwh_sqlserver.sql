-- ============================================================
-- KHO DỮ LIỆU SAKILA – SQL Server Version (T-SQL)
-- Chạy trong SSMS: mở file, nhấn F5 hoặc Execute
--
-- Lưu ý SQL Server không có multi-schema như MySQL.
-- Toàn bộ sẽ nằm trong 1 database [sakila_dwh],
-- chia thành 2 schema: [dim] và [fact]
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sakila_dwh')
    DROP DATABASE sakila_dwh;
GO

CREATE DATABASE sakila_dwh;
GO

USE sakila_dwh;
GO

CREATE SCHEMA dim;
GO
CREATE SCHEMA fact;
GO

-- ============================================================
-- dim.Date
-- ============================================================
CREATE TABLE dim.Date (
    date_key        INT          NOT NULL,
    date            DATE,
    day_of_week     INT,
    day_name        NVARCHAR(20),
    day_of_month    INT,
    day_of_year     INT,
    week_of_year    INT,
    month_of_year   INT,
    month_name      NVARCHAR(20),
    quarter_of_year INT,
    year            INT,
    is_weekend      BIT,
    is_holiday      BIT DEFAULT 0,
    CONSTRAINT PK_Date PRIMARY KEY (date_key)
);
GO

-- Dòng đặc biệt cho return_date chưa có
INSERT INTO dim.Date VALUES
(-1, NULL, NULL, N'Chưa trả', NULL, NULL, NULL, NULL, N'Chưa trả', NULL, NULL, NULL, 0);
GO

-- Sinh ngày tự động bằng vòng lặp T-SQL
DECLARE @cur  DATE = '2005-01-01';
DECLARE @stop DATE = '2006-12-31';

WHILE @cur <= @stop
BEGIN
    INSERT INTO dim.Date (
        date_key, date,
        day_of_week, day_name,
        day_of_month, day_of_year,
        week_of_year, month_of_year, month_name,
        quarter_of_year, year,
        is_weekend, is_holiday
    )
    VALUES (
        YEAR(@cur)*10000 + MONTH(@cur)*100 + DAY(@cur),
        @cur,
        DATEPART(WEEKDAY, @cur),
        DATENAME(WEEKDAY, @cur),
        DAY(@cur),
        DATEPART(DAYOFYEAR, @cur),
        DATEPART(WEEK, @cur),
        MONTH(@cur),
        DATENAME(MONTH, @cur),
        DATEPART(QUARTER, @cur),
        YEAR(@cur),
        CASE WHEN DATEPART(WEEKDAY, @cur) IN (1,7) THEN 1 ELSE 0 END,
        0
    );
    SET @cur = DATEADD(DAY, 1, @cur);
END;
GO

-- ============================================================
-- dim.Product
-- NOTE: SQL Server dùng linked server hoặc import thủ công
-- từ MySQL. Script này giả định bảng nguồn đã được import vào
-- staging schema [stg] trong cùng database.
--
-- Nếu chưa có linked server, xem hướng dẫn import ở cuối file.
-- ============================================================
CREATE TABLE dim.Product (
    product_key      INT          NOT NULL IDENTITY(1,1),
    film_id          INT          NOT NULL,
    title            NVARCHAR(255) NOT NULL,
    description      NVARCHAR(MAX),
    release_year     INT,
    language_name    NVARCHAR(50),
    rental_duration  INT,
    rental_rate      DECIMAL(4,2),
    length_minutes   INT,
    replacement_cost DECIMAL(5,2),
    rating           NVARCHAR(10),
    special_features NVARCHAR(255),
    category_id      INT,
    category_name    NVARCHAR(25),
    inventory_count  INT,
    is_active        BIT          DEFAULT 1,
    effective_date   DATE,
    source_system    NVARCHAR(30) DEFAULT 'SAKILA_INVENTORY',
    CONSTRAINT PK_Product PRIMARY KEY (product_key)
);
CREATE INDEX idx_film_id ON dim.Product (film_id);
GO

-- ============================================================
-- dim.Customer
-- ============================================================
CREATE TABLE dim.Customer (
    customer_key   INT           NOT NULL IDENTITY(1,1),
    customer_id    INT           NOT NULL,
    first_name     NVARCHAR(45),
    last_name      NVARCHAR(45),
    full_name      NVARCHAR(91),
    email          NVARCHAR(50),
    address        NVARCHAR(50),
    address2       NVARCHAR(50),
    district       NVARCHAR(20),
    postal_code    NVARCHAR(10),
    phone          NVARCHAR(20),
    city_id        INT,
    city_name      NVARCHAR(50),
    country_id     INT,
    country_name   NVARCHAR(50),
    store_id       INT,
    active         BIT,
    customer_class NVARCHAR(10) DEFAULT 'Bronze',
    create_date    DATETIME,
    is_current     BIT          DEFAULT 1,
    effective_date DATE,
    source_system  NVARCHAR(30) DEFAULT 'SAKILA_CRM',
    CONSTRAINT PK_Customer PRIMARY KEY (customer_key)
);
CREATE INDEX idx_customer_id ON dim.Customer (customer_id);
GO

-- ============================================================
-- dim.Geography_Store
-- ============================================================
CREATE TABLE dim.Geography_Store (
    store_key     INT           NOT NULL IDENTITY(1,1),
    store_id      INT           NOT NULL,
    store_name    NVARCHAR(50),
    manager_name  NVARCHAR(91),
    address       NVARCHAR(50),
    address2      NVARCHAR(50),
    district      NVARCHAR(20),
    postal_code   NVARCHAR(10),
    phone         NVARCHAR(20),
    city_id       INT,
    city_name     NVARCHAR(50),
    country_id    INT,
    country_name  NVARCHAR(50),
    is_active     BIT          DEFAULT 1,
    effective_date DATE,
    source_system NVARCHAR(30) DEFAULT 'SAKILA_HRM',
    CONSTRAINT PK_Geography_Store PRIMARY KEY (store_key)
);
CREATE INDEX idx_store_id ON dim.Geography_Store (store_id);
GO

-- ============================================================
-- dim.Staff
-- ============================================================
CREATE TABLE dim.Staff (
    staff_key      INT           NOT NULL IDENTITY(1,1),
    staff_id       INT           NOT NULL,
    first_name     NVARCHAR(45),
    last_name      NVARCHAR(45),
    full_name      NVARCHAR(91),
    email          NVARCHAR(50),
    username       NVARCHAR(16),
    active         BIT,
    store_id       INT,
    store_name     NVARCHAR(50),
    address        NVARCHAR(50),
    address2       NVARCHAR(50),
    district       NVARCHAR(20),
    city_name      NVARCHAR(50),
    country_name   NVARCHAR(50),
    is_current     BIT          DEFAULT 1,
    effective_date DATE,
    source_system  NVARCHAR(30) DEFAULT 'SAKILA_HRM',
    CONSTRAINT PK_Staff PRIMARY KEY (staff_key)
);
CREATE INDEX idx_staff_id ON dim.Staff (staff_id);
GO

-- ============================================================
-- fact.Sale (Transaction Fact)
-- Khác MySQL: DATEDIFF(end, start) → DATEDIFF(DAY, start, end)
--             GREATEST()           → CASE WHEN ... END
--             TINYINT              → BIT
--             AUTO_INCREMENT       → IDENTITY(1,1)
-- ============================================================
CREATE TABLE fact.Sale (
    sale_key                 INT          NOT NULL IDENTITY(1,1),
    rental_id                INT,
    rental_date_key          INT,
    return_date_key          INT,
    payment_date_key         INT,
    customer_key             INT,
    product_key              INT,
    store_key                INT,
    staff_key                INT,
    amount                   DECIMAL(5,2),
    rental_duration_expected INT,
    rental_duration_actual   INT,
    late_days                INT,
    is_late                  BIT,
    is_returned              BIT,
    replacement_cost         DECIMAL(5,2),
    last_update              DATETIME DEFAULT GETDATE(),
    CONSTRAINT PK_Sale PRIMARY KEY (sale_key)
);
CREATE INDEX idx_rental_date ON fact.Sale (rental_date_key);
CREATE INDEX idx_return_date ON fact.Sale (return_date_key);
CREATE INDEX idx_customer    ON fact.Sale (customer_key);
CREATE INDEX idx_product     ON fact.Sale (product_key);
CREATE INDEX idx_store       ON fact.Sale (store_key);
CREATE INDEX idx_staff       ON fact.Sale (staff_key);
CREATE INDEX idx_rental_id   ON fact.Sale (rental_id);
GO

-- ============================================================
-- fact.Film_Coverage (Factless Fact)
-- ============================================================
CREATE TABLE fact.Film_Coverage (
    date_key    INT NOT NULL,
    product_key INT NOT NULL,
    store_key   INT NOT NULL,
    CONSTRAINT PK_Film_Coverage PRIMARY KEY (date_key, product_key, store_key)
);
GO

-- ============================================================
-- AGGREGATE FACTS
-- ============================================================

CREATE TABLE fact.Sale_byCustomer (
    date_key         INT           NOT NULL,
    customer_key     INT           NOT NULL,
    store_key        INT           NOT NULL,
    customer_class   NVARCHAR(10),
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    late_count       INT,
    unreturned_count INT,
    total_late_days  INT,
    arpu             DECIMAL(10,2),
    CONSTRAINT PK_Sale_byCustomer PRIMARY KEY (date_key, customer_key, store_key)
);
GO

CREATE TABLE fact.Sale_byProduct (
    date_key            INT           NOT NULL,
    product_key         INT           NOT NULL,
    store_key           INT           NOT NULL,
    total_rentals       INT,
    total_amount        DECIMAL(10,2),
    avg_duration_actual DECIMAL(5,2),
    late_count          INT,
    CONSTRAINT PK_Sale_byProduct PRIMARY KEY (date_key, product_key, store_key)
);
GO

CREATE TABLE fact.Sale_byStore (
    date_key               INT           NOT NULL,
    store_key              INT           NOT NULL,
    total_rentals          INT,
    total_amount           DECIMAL(10,2),
    total_late_count       INT,
    unreturned_count       INT,
    total_replacement_risk DECIMAL(10,2),
    CONSTRAINT PK_Sale_byStore PRIMARY KEY (date_key, store_key)
);
GO

CREATE TABLE fact.Sale_byStaff (
    date_key        INT           NOT NULL,
    staff_key       INT           NOT NULL,
    store_key       INT           NOT NULL,
    total_rentals   INT,
    total_amount    DECIMAL(10,2),
    total_customers INT,
    arpo            DECIMAL(10,2),
    CONSTRAINT PK_Sale_byStaff PRIMARY KEY (date_key, staff_key, store_key)
);
GO

CREATE TABLE fact.Sale_byDate (
    date_key         INT           NOT NULL,
    store_key        INT           NOT NULL,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    total_late_count INT,
    late_rate        DECIMAL(5,2),
    CONSTRAINT PK_Sale_byDate PRIMARY KEY (date_key, store_key)
);
GO

CREATE TABLE fact.Sale_byCategory (
    date_key              INT           NOT NULL,
    product_key           INT           NOT NULL,
    store_key             INT           NOT NULL,
    total_rentals         INT,
    total_amount          DECIMAL(10,2),
    unique_customers      INT,
    avg_amount_per_rental DECIMAL(5,2),
    CONSTRAINT PK_Sale_byCategory PRIMARY KEY (date_key, product_key, store_key)
);
GO

CREATE TABLE fact.Sale_byRegion (
    date_key        INT           NOT NULL,
    customer_key    INT           NOT NULL,
    total_customers INT,
    total_rentals   INT,
    total_amount    DECIMAL(10,2),
    arpu            DECIMAL(10,2),
    CONSTRAINT PK_Sale_byRegion PRIMARY KEY (date_key, customer_key)
);
GO

-- ============================================================
-- STORED PROCEDURES ETL
-- Chạy sau khi đã import dữ liệu từ MySQL vào staging tables
-- ============================================================

-- ETL Fact_Sale từ staging
CREATE OR ALTER PROCEDURE fact.usp_load_Sale
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO fact.Sale (
        rental_id,
        rental_date_key, return_date_key, payment_date_key,
        customer_key, product_key, store_key, staff_key,
        amount, rental_duration_expected, rental_duration_actual,
        late_days, is_late, is_returned, replacement_cost
    )
    SELECT
        r.rental_id,
        COALESCE(d_r.date_key,   -1),
        COALESCE(d_ret.date_key, -1),
        COALESCE(d_p.date_key,   -1),
        dc.customer_key,
        dp.product_key,
        dg.store_key,
        ds.staff_key,
        p.amount,
        f.rental_duration,
        -- SQL Server: DATEDIFF(DAY, start, end) – ngược với MySQL
        DATEDIFF(DAY, r.rental_date, r.return_date),
        -- SQL Server không có GREATEST() – dùng CASE WHEN
        CASE
            WHEN r.return_date IS NULL THEN 0
            WHEN DATEDIFF(DAY,
                DATEADD(DAY, f.rental_duration, r.rental_date),
                r.return_date) > 0
            THEN DATEDIFF(DAY,
                DATEADD(DAY, f.rental_duration, r.rental_date),
                r.return_date)
            ELSE 0
        END,
        CASE
            WHEN r.return_date IS NOT NULL
             AND DATEDIFF(DAY,
                DATEADD(DAY, f.rental_duration, r.rental_date),
                r.return_date) > 0
            THEN 1 ELSE 0
        END,
        CASE WHEN r.return_date IS NOT NULL THEN 1 ELSE 0 END,
        f.replacement_cost
    -- Thay [stg] bằng tên staging schema/database của bạn
    FROM stg.rental             r
    JOIN stg.payment            p    ON r.rental_id    = p.rental_id
    JOIN stg.inventory          i    ON r.inventory_id = i.inventory_id
    JOIN stg.film               f    ON i.film_id      = f.film_id
    JOIN dim.Date               d_r  ON CAST(r.rental_date  AS DATE) = d_r.date
    LEFT JOIN dim.Date          d_ret ON CAST(r.return_date AS DATE) = d_ret.date
    JOIN dim.Date               d_p  ON CAST(p.payment_date AS DATE) = d_p.date
    JOIN dim.Customer           dc   ON r.customer_id = dc.customer_id  AND dc.is_current = 1
    JOIN dim.Product            dp   ON i.film_id     = dp.film_id      AND dp.is_active  = 1
    JOIN dim.Geography_Store    dg   ON i.store_id    = dg.store_id
    JOIN dim.Staff              ds   ON r.staff_id    = ds.staff_id     AND ds.is_current = 1;
END;
GO

-- ETL Aggregate Facts từ fact.Sale
CREATE OR ALTER PROCEDURE fact.usp_load_Aggregates
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE fact.Sale_byCustomer;
    TRUNCATE TABLE fact.Sale_byProduct;
    TRUNCATE TABLE fact.Sale_byStore;
    TRUNCATE TABLE fact.Sale_byStaff;
    TRUNCATE TABLE fact.Sale_byDate;
    TRUNCATE TABLE fact.Sale_byCategory;
    TRUNCATE TABLE fact.Sale_byRegion;

    -- byCustomer
    INSERT INTO fact.Sale_byCustomer
    SELECT
        fs.rental_date_key, fs.customer_key, fs.store_key,
        dc.customer_class,
        COUNT(*), SUM(fs.amount),
        SUM(CAST(fs.is_late AS INT)),
        SUM(CASE WHEN fs.is_returned = 0 THEN 1 ELSE 0 END),
        SUM(fs.late_days),
        SUM(fs.amount) / NULLIF(COUNT(DISTINCT fs.customer_key), 0)
    FROM fact.Sale fs
    JOIN dim.Customer dc ON fs.customer_key = dc.customer_key
    GROUP BY fs.rental_date_key, fs.customer_key, fs.store_key, dc.customer_class;

    -- byProduct
    INSERT INTO fact.Sale_byProduct
    SELECT
        rental_date_key, product_key, store_key,
        COUNT(*), SUM(amount), AVG(CAST(rental_duration_actual AS DECIMAL(5,2))),
        SUM(CAST(is_late AS INT))
    FROM fact.Sale
    GROUP BY rental_date_key, product_key, store_key;

    -- byStore
    INSERT INTO fact.Sale_byStore
    SELECT
        rental_date_key, store_key,
        COUNT(*), SUM(amount),
        SUM(CAST(is_late AS INT)),
        SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN is_returned = 0 THEN replacement_cost ELSE 0 END)
    FROM fact.Sale
    GROUP BY rental_date_key, store_key;

    -- byStaff
    INSERT INTO fact.Sale_byStaff
    SELECT
        rental_date_key, staff_key, store_key,
        COUNT(*), SUM(amount),
        COUNT(DISTINCT customer_key),
        SUM(amount) / NULLIF(COUNT(*), 0)
    FROM fact.Sale
    GROUP BY rental_date_key, staff_key, store_key;

    -- byDate
    INSERT INTO fact.Sale_byDate
    SELECT
        rental_date_key, store_key,
        COUNT(*), SUM(amount),
        SUM(CAST(is_late AS INT)),
        ROUND(CAST(SUM(CAST(is_late AS INT)) AS DECIMAL(10,2)) / NULLIF(COUNT(*),0) * 100, 2)
    FROM fact.Sale
    GROUP BY rental_date_key, store_key;

    -- byCategory
    INSERT INTO fact.Sale_byCategory
    SELECT
        rental_date_key, product_key, store_key,
        COUNT(*), SUM(amount),
        COUNT(DISTINCT customer_key),
        SUM(amount) / NULLIF(COUNT(*), 0)
    FROM fact.Sale
    GROUP BY rental_date_key, product_key, store_key;

    -- byRegion
    INSERT INTO fact.Sale_byRegion
    SELECT
        rental_date_key, customer_key,
        COUNT(DISTINCT customer_key),
        COUNT(*), SUM(amount),
        SUM(amount) / NULLIF(COUNT(DISTINCT customer_key), 0)
    FROM fact.Sale
    GROUP BY rental_date_key, customer_key;
END;
GO

-- ============================================================
-- KIỂM TRA SỐ DÒNG
-- ============================================================
SELECT 'dim.Date'              AS bang, COUNT(*) AS so_dong FROM dim.Date
UNION ALL SELECT 'dim.Product',             COUNT(*) FROM dim.Product
UNION ALL SELECT 'dim.Customer',            COUNT(*) FROM dim.Customer
UNION ALL SELECT 'dim.Geography_Store',     COUNT(*) FROM dim.Geography_Store
UNION ALL SELECT 'dim.Staff',               COUNT(*) FROM dim.Staff
UNION ALL SELECT 'fact.Sale',               COUNT(*) FROM fact.Sale
UNION ALL SELECT 'fact.Film_Coverage',      COUNT(*) FROM fact.Film_Coverage
UNION ALL SELECT 'fact.Sale_byCustomer',    COUNT(*) FROM fact.Sale_byCustomer
UNION ALL SELECT 'fact.Sale_byProduct',     COUNT(*) FROM fact.Sale_byProduct
UNION ALL SELECT 'fact.Sale_byStore',       COUNT(*) FROM fact.Sale_byStore
UNION ALL SELECT 'fact.Sale_byStaff',       COUNT(*) FROM fact.Sale_byStaff
UNION ALL SELECT 'fact.Sale_byDate',        COUNT(*) FROM fact.Sale_byDate
UNION ALL SELECT 'fact.Sale_byCategory',    COUNT(*) FROM fact.Sale_byCategory
UNION ALL SELECT 'fact.Sale_byRegion',      COUNT(*) FROM fact.Sale_byRegion;
GO

-- ============================================================
-- HƯỚNG DẪN IMPORT DỮ LIỆU TỪ MYSQL VÀO SQL SERVER
-- ============================================================
-- SQL Server không kết nối trực tiếp vào MySQL như MySQL kết nối
-- vào schema khác. Có 3 cách:
--
-- CÁCH 1 – Dễ nhất: Dùng SSMS Import Wizard
--   1. Chuột phải vào database sakila_dwh → Tasks → Import Data
--   2. Data Source: MySQL ODBC Driver (cài trước)
--   3. Destination: SQL Server Native Client
--   4. Chọn các bảng: rental, payment, inventory, film,
--      customer, staff, store, address, city, country, category
--   5. Import vào schema [stg] (staging)
--   Sau đó chạy các stored procedure ETL ở trên.
--
-- CÁCH 2 – Dùng Python (nếu có cài Python):
--   pip install pymysql pyodbc pandas sqlalchemy
--   Chạy script Python để đọc từ MySQL và ghi vào SQL Server.
--
-- CÁCH 3 – Export CSV từ phpMyAdmin rồi Import vào SSMS
--   1. phpMyAdmin → Export từng bảng ra CSV
--   2. SSMS → Chuột phải bảng → Import Flat File
--   Cách này không cần cài thêm gì, phù hợp nhất với XAMPP.
-- ============================================================
