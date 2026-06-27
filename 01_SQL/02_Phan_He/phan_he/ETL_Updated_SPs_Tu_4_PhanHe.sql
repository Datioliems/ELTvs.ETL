-- ============================================================
-- FILE: ETL_Updated_SPs_Tu_4_PhanHe.sql
-- MỤC ĐÍCH: Cập nhật 7 Stored Procedures để đọc từ
--           4 database phân hệ thay vì sakila.dbo.* gốc
-- CHẠY TRÊN: SSMS — database Sakila_DW
-- CHẠY SAU: SQLServer_Phan_He_OLTP.sql đã tạo xong 4 phân hệ
-- ============================================================

USE Sakila_DW;
GO

-- ============================================================
-- SP 1: Load Dim_Geography_Store
-- Nguồn mới: Sakila_HRM.dbo.store + address + city + country
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_Load_Dim_Geography_Store
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT;

    IF OBJECT_ID('tempdb..#Stage_Store','U') IS NOT NULL DROP TABLE #Stage_Store;

    SELECT
        s.store_id,
        a.address,
        a.district,
        a.postal_code,
        a.phone,
        a.city_id,
        ci.city,
        ci.country_id,
        co.country
    INTO #Stage_Store
    FROM Sakila_HRM.dbo.store   s
    LEFT JOIN Sakila_HRM.dbo.address a   ON s.address_id  = a.address_id
    LEFT JOIN Sakila_HRM.dbo.city    ci  ON a.city_id     = ci.city_id
    LEFT JOIN Sakila_HRM.dbo.country co  ON ci.country_id = co.country_id;

    UPDATE dw.Dim_Geography_Store
    SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, update_date = GETDATE()
    WHERE is_current = 1
      AND store_id IN (
        SELECT s.store_id FROM #Stage_Store s
        INNER JOIN dw.Dim_Geography_Store d ON s.store_id = d.store_id AND d.is_current = 1
        WHERE ISNULL(s.address,'') <> ISNULL(d.address,'')
           OR ISNULL(s.city,'')    <> ISNULL(d.city,'')
    );

    INSERT INTO dw.Dim_Geography_Store (
        store_id, address, district, postal_code, phone,
        city_id, city, country_id, country,
        effective_date, expiry_date, is_current, create_date, update_date, source_system
    )
    SELECT s.store_id, s.address, s.district, s.postal_code, s.phone,
           s.city_id, s.city, s.country_id, s.country,
           CAST(GETDATE() AS DATE), NULL, 1, GETDATE(), GETDATE(), 'Sakila_HRM'
    FROM #Stage_Store s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.Dim_Geography_Store d
        WHERE d.store_id = s.store_id AND d.is_current = 1
    );

    DROP TABLE #Stage_Store;
    SELECT @cnt = COUNT(*) FROM dw.Dim_Geography_Store WHERE is_current = 1;
    PRINT 'Dim_Geography_Store: ' + CAST(@cnt AS VARCHAR) + ' dòng (nguồn: Sakila_HRM)';
END;
GO

-- ============================================================
-- SP 2: Load Dim_Staff
-- Nguồn mới: Sakila_HRM.dbo.staff + store + address + city + country
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_Load_Dim_Staff
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT;

    IF OBJECT_ID('tempdb..#Stage_Staff','U') IS NOT NULL DROP TABLE #Stage_Staff;

    SELECT
        st.staff_id,
        st.first_name,
        st.last_name,
        st.first_name + ' ' + st.last_name              AS full_name,
        st.email,
        st.username,
        CAST(st.active AS BIT)                          AS active,
        st.store_id,
        'Sakila Store #' + CAST(st.store_id AS VARCHAR) AS store_name,
        a.address,
        a.district,
        ci.city    AS city_name,
        co.country AS country_name
    INTO #Stage_Staff
    FROM Sakila_HRM.dbo.staff   st
    LEFT JOIN Sakila_HRM.dbo.address a   ON st.address_id = a.address_id
    LEFT JOIN Sakila_HRM.dbo.city    ci  ON a.city_id     = ci.city_id
    LEFT JOIN Sakila_HRM.dbo.country co  ON ci.country_id = co.country_id;

    UPDATE dw.Dim_Staff
    SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, updated_date = GETDATE()
    WHERE is_current = 1
      AND staff_id IN (
        SELECT s.staff_id FROM #Stage_Staff s
        INNER JOIN dw.Dim_Staff d ON s.staff_id = d.staff_id AND d.is_current = 1
        WHERE s.store_id <> d.store_id OR s.active <> d.active
    );

    INSERT INTO dw.Dim_Staff (
        staff_id, first_name, last_name, full_name, email, username, active,
        store_id, store_name, address, district, city_name, country_name,
        effective_date, expiry_date, is_current, created_date, updated_date, source_system
    )
    SELECT s.staff_id, s.first_name, s.last_name, s.full_name, s.email, s.username, s.active,
           s.store_id, s.store_name, s.address, s.district, s.city_name, s.country_name,
           CAST(GETDATE() AS DATE), NULL, 1, GETDATE(), GETDATE(), 'Sakila_HRM'
    FROM #Stage_Staff s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.Dim_Staff d WHERE d.staff_id = s.staff_id AND d.is_current = 1
    );

    UPDATE d SET d.email = s.email, d.updated_date = GETDATE()
    FROM dw.Dim_Staff d INNER JOIN #Stage_Staff s ON d.staff_id = s.staff_id AND d.is_current = 1
    WHERE ISNULL(d.email,'') <> ISNULL(s.email,'');

    DROP TABLE #Stage_Staff;
    SELECT @cnt = COUNT(*) FROM dw.Dim_Staff WHERE is_current = 1;
    PRINT 'Dim_Staff: ' + CAST(@cnt AS VARCHAR) + ' dòng (nguồn: Sakila_HRM)';
END;
GO

-- ============================================================
-- SP 3: Load Dim_Customer
-- Nguồn mới: Sakila_CRM.dbo.customer + address + city + country
--            + Sakila_Sales.dbo.payment (để tính hạng)
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_Load_Dim_Customer
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT;
    DECLARE @p90 DECIMAL(10,2);
    DECLARE @p70 DECIMAL(10,2);

    IF OBJECT_ID('tempdb..#Stage_Customer','U') IS NOT NULL DROP TABLE #Stage_Customer;
    IF OBJECT_ID('tempdb..#CustomerRevenue','U') IS NOT NULL DROP TABLE #CustomerRevenue;

    -- Tính doanh thu từ Sakila_Sales
    SELECT customer_id, SUM(amount) AS total_amount
    INTO #CustomerRevenue
    FROM Sakila_Sales.dbo.payment
    GROUP BY customer_id;

    SELECT @p90 = PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_amount) OVER ()
    FROM #CustomerRevenue;

    SELECT @p70 = PERCENTILE_CONT(0.70) WITHIN GROUP (ORDER BY total_amount) OVER ()
    FROM #CustomerRevenue;

    -- Staging từ Sakila_CRM
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.first_name + ' ' + c.last_name AS full_name,
        c.email,
        a.address,
        ci.city,
        co.country,
        CASE
            WHEN ISNULL(rev.total_amount, 0) >= @p90 THEN N'Vàng'
            WHEN ISNULL(rev.total_amount, 0) >= @p70 THEN N'Bạc'
            ELSE N'Đồng'
        END AS customer_class
    INTO #Stage_Customer
    FROM Sakila_CRM.dbo.customer c
    LEFT JOIN Sakila_CRM.dbo.address a   ON c.address_id  = a.address_id
    LEFT JOIN Sakila_CRM.dbo.city    ci  ON a.city_id     = ci.city_id
    LEFT JOIN Sakila_CRM.dbo.country co  ON ci.country_id = co.country_id
    LEFT JOIN #CustomerRevenue       rev ON c.customer_id = rev.customer_id;

    UPDATE dw.Dim_Customer
    SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, update_date = GETDATE()
    WHERE is_current = 1
      AND customer_id IN (
        SELECT s.customer_id FROM #Stage_Customer s
        INNER JOIN dw.Dim_Customer d ON s.customer_id = d.customer_id AND d.is_current = 1
        WHERE ISNULL(s.city,'')    <> ISNULL(d.city,'')
           OR ISNULL(s.country,'') <> ISNULL(d.country,'')
    );

    INSERT INTO dw.Dim_Customer (
        customer_id, first_name, last_name, full_name, email,
        address, city, country, customer_class,
        effective_date, expiry_date, is_current, create_date, update_date, source_system
    )
    SELECT s.customer_id, s.first_name, s.last_name, s.full_name, s.email,
           s.address, s.city, s.country, s.customer_class,
           CAST(GETDATE() AS DATE), NULL, 1, GETDATE(), GETDATE(), 'Sakila_CRM'
    FROM #Stage_Customer s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.Dim_Customer d WHERE d.customer_id = s.customer_id AND d.is_current = 1
    );

    UPDATE d
    SET d.email = s.email, d.customer_class = s.customer_class, d.update_date = GETDATE()
    FROM dw.Dim_Customer d
    INNER JOIN #Stage_Customer s ON d.customer_id = s.customer_id AND d.is_current = 1
    WHERE ISNULL(d.email,'')         <> ISNULL(s.email,'')
       OR ISNULL(d.customer_class,'') <> ISNULL(s.customer_class,'');

    DROP TABLE #Stage_Customer;
    DROP TABLE #CustomerRevenue;
    SELECT @cnt = COUNT(*) FROM dw.Dim_Customer WHERE is_current = 1;
    PRINT 'Dim_Customer: ' + CAST(@cnt AS VARCHAR) + ' dòng (nguồn: Sakila_CRM + Sakila_Sales)';
END;
GO

-- ============================================================
-- SP 4: Load Dim_Product
-- Nguồn mới: Sakila_Inventory.dbo.film + category + inventory + language
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_Load_Dim_Product
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT;

    IF OBJECT_ID('tempdb..#Stage_Product','U') IS NOT NULL DROP TABLE #Stage_Product;

    SELECT
        f.film_id,
        f.title,
        f.description,
        CAST(f.release_year AS SMALLINT)       AS release_year,
        f.language_id,
        ISNULL(l.name,'Unknown')               AS language_name,
        f.rental_duration,
        f.rental_rate,
        f.length,
        f.replacement_cost,
        f.rating,
        fc.category_id,
        c.name                                 AS category_name,
        ISNULL(inv.inventory_count, 0)         AS inventory_count
    INTO #Stage_Product
    FROM Sakila_Inventory.dbo.film f
    LEFT JOIN Sakila_Inventory.dbo.language      l   ON f.language_id  = l.language_id
    LEFT JOIN Sakila_Inventory.dbo.film_category fc  ON f.film_id      = fc.film_id
    LEFT JOIN Sakila_Inventory.dbo.category      c   ON fc.category_id = c.category_id
    LEFT JOIN (
        SELECT film_id, COUNT(*) AS inventory_count
        FROM Sakila_Inventory.dbo.inventory
        GROUP BY film_id
    ) inv ON f.film_id = inv.film_id;

    UPDATE dw.Dim_Product
    SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, updated_date = GETDATE()
    WHERE is_current = 1
      AND film_id IN (
        SELECT s.film_id FROM #Stage_Product s
        INNER JOIN dw.Dim_Product d ON s.film_id = d.film_id AND d.is_current = 1
        WHERE s.rental_rate      <> d.rental_rate
           OR s.category_name    <> ISNULL(d.category_name,'')
           OR s.rental_duration  <> ISNULL(d.rental_duration,0)
           OR s.replacement_cost <> ISNULL(d.replacement_cost,0)
           OR s.rating           <> ISNULL(d.rating,'')
           OR s.inventory_count  <> ISNULL(d.inventory_count,0)
    );

    INSERT INTO dw.Dim_Product (
        film_id, title, description, release_year, language_id, language_name,
        rental_duration, rental_rate, length, replacement_cost, rating,
        category_id, category_name, inventory_count,
        effective_date, expiry_date, is_current, created_date, updated_date, source_system
    )
    SELECT s.film_id, s.title, s.description, s.release_year, s.language_id, s.language_name,
           s.rental_duration, s.rental_rate, s.length, s.replacement_cost, s.rating,
           s.category_id, s.category_name, s.inventory_count,
           CAST(GETDATE() AS DATE), NULL, 1, GETDATE(), GETDATE(), 'Sakila_Inventory'
    FROM #Stage_Product s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.Dim_Product d WHERE d.film_id = s.film_id AND d.is_current = 1
    );

    UPDATE d
    SET d.title = s.title, d.description = s.description, d.length = s.length, d.updated_date = GETDATE()
    FROM dw.Dim_Product d
    INNER JOIN #Stage_Product s ON d.film_id = s.film_id AND d.is_current = 1
    WHERE d.title <> s.title OR d.length <> ISNULL(s.length,0);

    DROP TABLE #Stage_Product;
    SELECT @cnt = COUNT(*) FROM dw.Dim_Product WHERE is_current = 1;
    PRINT 'Dim_Product: ' + CAST(@cnt AS VARCHAR) + ' dòng (nguồn: Sakila_Inventory)';
END;
GO

-- ============================================================
-- SP 5: Load Fact_Sale
-- Nguồn mới: Sakila_Sales.dbo.rental + payment
--            + Sakila_Inventory.dbo.inventory + film (để lấy film_id, store_id)
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_Load_Fact_Sale
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT;

    IF OBJECT_ID('tempdb..#Stage_Fact','U') IS NOT NULL DROP TABLE #Stage_Fact;

    SELECT
        r.rental_id,
        CAST(FORMAT(r.rental_date,  'yyyyMMdd') AS INT)     AS rental_date_key,
        CASE
            WHEN r.return_date IS NULL THEN -1
            ELSE CAST(FORMAT(r.return_date, 'yyyyMMdd') AS INT)
        END                                                 AS return_date_key,
        CAST(FORMAT(p.payment_date, 'yyyyMMdd') AS INT)     AS payment_date_key,
        r.customer_id,
        i.film_id,
        r.staff_id,
        i.store_id,
        ISNULL(p.amount, 0)                                 AS amount,
        f.rental_duration                                   AS rental_duration_expected,
        CASE
            WHEN r.return_date IS NULL THEN NULL
            ELSE DATEDIFF(DAY, r.rental_date, r.return_date)
        END                                                 AS rental_duration_actual,
        CASE
            WHEN r.return_date IS NULL THEN 0
            WHEN DATEDIFF(DAY,r.rental_date,r.return_date) > f.rental_duration
            THEN DATEDIFF(DAY,r.rental_date,r.return_date) - f.rental_duration
            ELSE 0
        END                                                 AS late_days,
        CASE
            WHEN r.return_date IS NULL THEN 0
            WHEN DATEDIFF(DAY,r.rental_date,r.return_date) > f.rental_duration THEN 1
            ELSE 0
        END                                                 AS is_late,
        CASE WHEN r.return_date IS NULL THEN 0 ELSE 1 END   AS is_returned,
        f.replacement_cost
    INTO #Stage_Fact
    -- rental từ Sakila_Sales
    FROM Sakila_Sales.dbo.rental     r
    -- inventory và film từ Sakila_Inventory
    INNER JOIN Sakila_Inventory.dbo.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN Sakila_Inventory.dbo.film      f ON i.film_id      = f.film_id
    -- payment từ Sakila_Sales
    LEFT JOIN  Sakila_Sales.dbo.payment       p ON r.rental_id    = p.rental_id;

    TRUNCATE TABLE dw.Fact_Sale;

    INSERT INTO dw.Fact_Sale (
        rental_id, rental_date_key, return_date_key, payment_date_key,
        customer_key, product_key, store_key, staff_key,
        amount, rental_duration_expected, rental_duration_actual,
        late_days, is_late, is_returned, replacement_cost
    )
    SELECT
        s.rental_id, s.rental_date_key, s.return_date_key, s.payment_date_key,
        dc.customer_key, dp.product_key, dgs.store_key, dst.staff_key,
        s.amount, s.rental_duration_expected, s.rental_duration_actual,
        s.late_days, s.is_late, s.is_returned, s.replacement_cost
    FROM #Stage_Fact s
    INNER JOIN dw.Dim_Customer        dc  ON s.customer_id = dc.customer_id AND dc.is_current = 1
    INNER JOIN dw.Dim_Product         dp  ON s.film_id     = dp.film_id     AND dp.is_current = 1
    INNER JOIN dw.Dim_Geography_Store dgs ON s.store_id    = dgs.store_id   AND dgs.is_current = 1
    INNER JOIN dw.Dim_Staff           dst ON s.staff_id    = dst.staff_id   AND dst.is_current = 1
    INNER JOIN dw.Dim_Date dd_r  ON s.rental_date_key  = dd_r.date_key
    INNER JOIN dw.Dim_Date dd_p  ON s.payment_date_key = dd_p.date_key
    INNER JOIN dw.Dim_Date dd_rt ON s.return_date_key  = dd_rt.date_key;

    DROP TABLE #Stage_Fact;
    SELECT @cnt = COUNT(*) FROM dw.Fact_Sale;
    PRINT 'Fact_Sale: ' + CAST(@cnt AS VARCHAR) + ' dòng (nguồn: Sakila_Sales + Sakila_Inventory)';
END;
GO

-- SP 6 và SP 7 không thay đổi (đọc từ chính Sakila_DW)
-- Chạy lại 2 SP này nếu cần:
-- EXEC dw.usp_Load_Aggregate_Facts;
-- EXEC dw.usp_Create_Views;

PRINT '=== Cập nhật ETL SPs từ 4 phân hệ thành công ===';
GO
