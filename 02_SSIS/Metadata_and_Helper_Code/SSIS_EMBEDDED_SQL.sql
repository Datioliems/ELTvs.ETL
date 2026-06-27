-- SQL Task statement 1
SELECT table_name, last_run
FROM dw.ETL_Log
ORDER BY table_name

GO

-- SQL Task statement 2
UPDATE dw.ETL_Log SET last_run = '2026-05-24 00:31:27' WHERE table_name IN ('Dim_Customer','Dim_Product','Dim_Staff','Dim_Geography_Store','Fact_Sale','Dim_Date')

GO

-- SQL Task statement 3
-- ============================================================
-- FILE: 05_Load_Aggregate_Facts.sql
-- FIX: CAST(is_late AS INT) và CAST(is_returned AS INT)
--      trước khi SUM vì kiểu BIT không SUM trực tiếp được
-- CONNECTION: CM_SS_DW
-- ============================================================
USE Sakila_DW;
GO

PRINT 'Bắt đầu load Aggregate Facts: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- ============================================================
-- 1. Fact_Sale_byCustomer
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byCustomer;

INSERT INTO dw.Fact_Sale_byCustomer (
    date_key, customer_key, store_key, staff_key,
    customer_class, total_amount, rental_count, late_count
)
SELECT
    fs.rental_date_key          AS date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class,
    SUM(fs.amount)              AS total_amount,
    COUNT(*)                    AS rental_count,
    SUM(CAST(fs.is_late AS INT)) AS late_count   -- FIX: BIT → INT
FROM dw.Fact_Sale fs
JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
                       AND dc.is_current   = 1
GROUP BY
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key,
    fs.staff_key,
    dc.customer_class;

PRINT '+ Fact_Sale_byCustomer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 2. Fact_Sale_byProduct
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byProduct;

INSERT INTO dw.Fact_Sale_byProduct (
    date_key, product_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.product_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.product_key,
    fs.store_key;

PRINT '+ Fact_Sale_byProduct: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 3. Fact_Sale_byStore
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byStore;

INSERT INTO dw.Fact_Sale_byStore (
    date_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.store_key;

PRINT '+ Fact_Sale_byStore: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 4. Fact_Sale_byStaff
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byStaff;

INSERT INTO dw.Fact_Sale_byStaff (
    date_key, store_key, staff_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.store_key,
    fs.staff_key,
SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.store_key,
    fs.staff_key;

PRINT '+ Fact_Sale_byStaff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- 5. Fact_Sale_byDate
-- ============================================================
TRUNCATE TABLE dw.Fact_Sale_byDate;

INSERT INTO dw.Fact_Sale_byDate (
    date_key, customer_key, store_key,
    total_amount, rental_count
)
SELECT
    fs.rental_date_key  AS date_key,
    fs.customer_key,
    fs.store_key,
    SUM(fs.amount)      AS total_amount,
    COUNT(*)            AS rental_count
FROM dw.Fact_Sale fs
GROUP BY
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key;

PRINT '+ Fact_Sale_byDate: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
GO

-- ============================================================
-- Kiểm tra kết quả
-- ============================================================
PRINT '';
PRINT '=== Tổng kết Aggregate Tables ===';
SELECT 'Fact_Sale_byCustomer' AS bang, COUNT(*) AS so_dong FROM dw.Fact_Sale_byCustomer
UNION ALL
SELECT 'Fact_Sale_byProduct',          COUNT(*) FROM dw.Fact_Sale_byProduct
UNION ALL
SELECT 'Fact_Sale_byStore',            COUNT(*) FROM dw.Fact_Sale_byStore
UNION ALL
SELECT 'Fact_Sale_byStaff',            COUNT(*) FROM dw.Fact_Sale_byStaff
UNION ALL
SELECT 'Fact_Sale_byDate',             COUNT(*) FROM dw.Fact_Sale_byDate
UNION ALL
SELECT '--- Fact_Sale (goc) ---',      COUNT(*) FROM dw.Fact_Sale;

PRINT 'Hoàn thành: ' + CONVERT(VARCHAR, GETDATE(), 120);
GO

GO

-- SQL Task statement 4
USE Sakila_DW;

-- Chỉ sinh Dim_Date nếu chưa có dữ liệu ngày nào
IF NOT EXISTS (SELECT 1 FROM dw.Dim_Date WHERE date_key > 0)
BEGIN
    -- Đảm bảo dòng -1 tồn tại
    IF NOT EXISTS (SELECT 1 FROM dw.Dim_Date WHERE date_key = -1)
    BEGIN
        INSERT INTO dw.Dim_Date VALUES
            (-1,'1900-01-01',0,N'Unknown',0,0,0,0,
             N'Unknown',0,0,0,0,N'Chua tra dia')
    END

    -- Sinh ngày 2000-2030
    DECLARE @StartDate DATE = '2000-01-01'
    DECLARE @EndDate   DATE = '2030-12-31'
    DECLARE @Current   DATE = @StartDate

    WHILE @Current <= @EndDate
    BEGIN
        INSERT INTO dw.Dim_Date (
            date_key, date, day_of_week, day_name, day_of_month,
            day_of_year, week_of_year, month_of_year, month_name,
            quarter_of_year, year, is_weekend, is_special_day, special_day
        )
        VALUES (
            CAST(FORMAT(@Current,'yyyyMMdd') AS INT),
            @Current,
            DATEPART(WEEKDAY,@Current),
            DATENAME(WEEKDAY,@Current),
            DAY(@Current),
            DATEPART(DAYOFYEAR,@Current),
            DATEPART(ISO_WEEK,@Current),
            MONTH(@Current),
            DATENAME(MONTH,@Current),
            DATEPART(QUARTER,@Current),
            YEAR(@Current),
            CASE WHEN DATEPART(WEEKDAY,@Current) IN (1,7) THEN 1 ELSE 0 END,
            CASE WHEN FORMAT(@Current,'MM-dd') IN
                ('01-01','04-30','05-01','09-02','12-25','11-24')
                THEN 1 ELSE 0 END,
            CASE FORMAT(@Current,'MM-dd')
                WHEN '01-01' THEN N'Tet Duong Lich'
                WHEN '04-30' THEN N'Ngay Giai Phong Mien Nam'
                WHEN '05-01' THEN N'Quoc Te Lao Dong'
                WHEN '09-02' THEN N'Quoc Khanh'
                WHEN '12-25' THEN N'Giang Sinh'
                WHEN '11-24' THEN N'Ngay Van Hoa Viet Nam'
                ELSE NULL END
        )
        SET @Current = DATEADD(DAY,1,@Current)
    END

    -- Kiểm tra kết quả
    SELECT COUNT(*) AS tong_dong FROM dw.Dim_Date
END
ELSE
BEGIN
    -- Đã có dữ liệu → bỏ qua, không cần sinh lại
    SELECT COUNT(*) AS tong_dong_hien_tai FROM dw.Dim_Date
END

GO

-- Data Flow SQL statement 5
SELECT customer_id, customer_key, full_name, email, address, city, country, customer_class 
FROM dw.Dim_Customer 
WHERE is_current = 1

GO

-- Data Flow SQL statement 6
SELECT customer_id, SUM(amount) AS total_amount
FROM     payment
GROUP BY customer_id

GO

-- Data Flow SQL statement 7
UPDATE dw.Dim_Customer
    SET is_current   = 0,
        expiry_date  = GETDATE(),
        update_date  = GETDATE()
    WHERE customer_key = ?

GO

-- Data Flow SQL statement 8
UPDATE dw.Dim_Customer
    SET email          = ?,
        customer_class = ?,
        update_date    = GETDATE()
    WHERE customer_key = ?


GO

-- Data Flow SQL statement 9
SELECT
    CAST(c.customer_id AS INT)                              AS customer_id,
    CAST(
        ISNULL(c.first_name, N'') + N' ' + ISNULL(c.last_name, N'')
        AS NVARCHAR(91))                                    AS full_name,
    CAST(ISNULL(c.email,   N'') AS NVARCHAR(50))            AS email,
    CAST(ISNULL(a.address, N'') AS NVARCHAR(50))            AS address,
    CAST(ISNULL(ci.city,   N'') AS NVARCHAR(50))            AS city,
    CAST(ISNULL(co.country,N'') AS NVARCHAR(50))            AS country
FROM Sakila_CRM.dbo.customer  c
LEFT JOIN Sakila_CRM.dbo.address  a  ON c.address_id  = a.address_id
LEFT JOIN Sakila_CRM.dbo.city     ci ON a.city_id     = ci.city_id
LEFT JOIN Sakila_CRM.dbo.country  co ON ci.country_id = co.country_id
WHERE c.last_update > ?

GO

-- Data Flow SQL statement 10
UPDATE [dw].[Dim_Geography_Store] SET [is_current] = ? WHERE [store_id] = ? AND [is_current] = '1'

GO

-- Data Flow SQL statement 11
UPDATE [dw].[Dim_Geography_Store] SET [phone] = ? WHERE [store_id] = ? AND [is_current] = '1'

GO

-- Data Flow SQL statement 12
SELECT
    CAST(s.store_id          AS INT)          AS store_id,
    CAST(a.address           AS NVARCHAR(50)) AS address,
    CAST(a.district          AS NVARCHAR(20)) AS district,
    CAST(a.postal_code       AS NVARCHAR(10)) AS postal_code,
    CAST(a.phone             AS NVARCHAR(20)) AS phone,
    CAST(ci.city_id          AS INT)          AS city_id,
    CAST(ci.city             AS NVARCHAR(50)) AS city,
    CAST(co.country_id       AS INT)          AS country_id,
    CAST(co.country          AS NVARCHAR(50)) AS country,
    CAST(s.manager_staff_id  AS INT)          AS manager_staff_id
FROM store AS s
INNER JOIN address AS a  ON s.address_id  = a.address_id
INNER JOIN city    AS ci ON a.city_id     = ci.city_id
INNER JOIN country AS co ON ci.country_id = co.country_id
WHERE s.last_update > ?

GO

-- Data Flow SQL statement 13
SELECT [address], [city], [city_id], [country], [country_id], [district], [manager_staff_id], [phone], [postal_code], [store_id],[is_current] FROM [dw].[Dim_Geography_Store]

GO

-- Data Flow SQL statement 14
SELECT film_id, product_key,
         rental_rate, rating, category_name, inventory_count 
FROM dw.Dim_Product
  WHERE is_current = 1

GO

-- Data Flow SQL statement 15
SELECT
    f.film_id,
    f.title,
    CAST(f.description AS CHAR(255)) AS description,
    f.release_year,
f.language_id,
    l.name              AS language_name,
    f.rental_duration,
    f.rental_rate,
    f.length,
    f.replacement_cost,
    f.rating,
c.category_id,
    c.name              AS category_name,
    COUNT(i.inventory_id) AS inventory_count,
MAX(f.last_update)               AS last_update
FROM film f
JOIN `language`      l  ON f.language_id  = l.language_id
JOIN film_category   fc ON f.film_id      = fc.film_id
JOIN category        c  ON fc.category_id = c.category_id
LEFT JOIN inventory  i  ON f.film_id      = i.film_id
GROUP BY
    f.film_id, f.title, f.description, f.release_year,
    l.name, f.rental_duration, f.rental_rate,
    f.length, f.replacement_cost, f.rating, c.name

GO

-- Data Flow SQL statement 16
UPDATE dw.Dim_Product
SET is_current   = 0,
    expiry_date  = GETDATE(),
    updated_date = GETDATE()
WHERE product_key = ?

GO

-- Data Flow SQL statement 17
UPDATE dw.Dim_Product
    SET inventory_count = ?,
        updated_date    = GETDATE()
    WHERE product_key = ?

GO

-- Data Flow SQL statement 18
UPDATE [dw].[Dim_Staff] SET [is_current] = ? WHERE [staff_id] = ? AND [is_current] = '1'

GO

-- Data Flow SQL statement 19
UPDATE [dw].[Dim_Staff] SET [active] = ?,[email] = ?,[username] = ? WHERE [staff_id] = ? AND [is_current] = '1'

GO

-- Data Flow SQL statement 20
SELECT CAST(st.staff_id AS INT) AS staff_id, CAST(st.first_name AS NVARCHAR(45)) AS first_name, CAST(st.last_name AS NVARCHAR(45)) AS last_name, CAST(st.first_name + ' ' + st.last_name AS NVARCHAR(91)) AS full_name, 
                  CAST(st.email AS NVARCHAR(50)) AS email, CAST(st.username AS NVARCHAR(16)) AS username, CAST(st.active AS BIT) AS active, CAST(st.store_id AS INT) AS store_id, CAST(a.address AS NVARCHAR(50)) AS address, 
                  CAST(a.district AS NVARCHAR(20)) AS district, CAST(ci.city AS NVARCHAR(50)) AS city_name, CAST(co.country AS NVARCHAR(50)) AS country_name
FROM     staff AS st INNER JOIN
                  address AS a ON st.address_id = a.address_id INNER JOIN
                  city AS ci ON a.city_id = ci.city_id INNER JOIN
                  country AS co ON ci.country_id = co.country_id
WHERE  (st.last_update > ?)

GO

-- Data Flow SQL statement 21
SELECT [active], [address], [city_name], [country_name], [district], [email], [first_name], [full_name], [last_name], [staff_id], [store_id], [username],[is_current] FROM [dw].[Dim_Staff]

GO

-- Data Flow SQL statement 22
SELECT customer_id, customer_key
  FROM dw.Dim_Customer WHERE is_current = 1

GO

-- Data Flow SQL statement 23
SELECT date_key FROM dw.Dim_Date

GO

-- Data Flow SQL statement 24
SELECT film_id, product_key
  FROM dw.Dim_Product WHERE is_current = 1

GO

-- Data Flow SQL statement 25
SELECT date_key FROM dw.Dim_Date

GO

-- Data Flow SQL statement 26
select * from [dw].[Fact_Sale]

GO

-- Data Flow SQL statement 27
SELECT date_key FROM dw.Dim_Date

GO

-- Data Flow SQL statement 28
SELECT staff_id, staff_key
  FROM dw.Dim_Staff WHERE is_current = 1

GO

-- Data Flow SQL statement 29
SELECT store_id, store_key
  FROM dw.Dim_Geography_Store WHERE is_current = 1

GO

-- Data Flow SQL statement 30
SELECT
    r.rental_id,
    CAST(FORMAT(r.rental_date,  'yyyyMMdd') AS INT) AS rental_date_src,
    CASE WHEN r.return_date IS NULL THEN -1
         ELSE CAST(FORMAT(r.return_date, 'yyyyMMdd') AS INT)
    END                                             AS return_date_src,
    CAST(FORMAT(p.payment_date, 'yyyyMMdd') AS INT) AS payment_date_src,
    CAST(r.customer_id  AS INT)                     AS customer_id,
    CAST(i.film_id      AS INT)                     AS film_id,
    CAST(r.staff_id     AS INT)                     AS staff_id,
    CAST(i.store_id     AS INT)                     AS store_id,
    ISNULL(p.amount, 0)                             AS amount,
    CAST(f.rental_duration AS INT)                  AS rental_duration_expected,
    CASE WHEN r.return_date IS NULL THEN NULL
         ELSE DATEDIFF(DAY, r.rental_date, r.return_date)
    END                                             AS rental_duration_actual,
    CASE WHEN r.return_date IS NULL THEN 0
         WHEN DATEDIFF(DAY,r.rental_date,r.return_date) > f.rental_duration
         THEN DATEDIFF(DAY,r.rental_date,r.return_date) - f.rental_duration
         ELSE 0
    END                                             AS late_days,
    CASE WHEN r.return_date IS NULL THEN 0
         WHEN DATEDIFF(DAY,r.rental_date,r.return_date) > f.rental_duration THEN 1
         ELSE 0
    END                                             AS is_late,
    CASE WHEN r.return_date IS NULL THEN 0 ELSE 1
    END                                             AS is_returned,
    f.replacement_cost
FROM Sakila_Sales.dbo.rental r
JOIN Sakila_Inventory.dbo.inventory i ON r.inventory_id = i.inventory_id
JOIN Sakila_Inventory.dbo.film      f ON i.film_id      = f.film_id
LEFT JOIN Sakila_Sales.dbo.payment  p ON r.rental_id    = p.rental_id
WHERE r.last_update > ?

GO

