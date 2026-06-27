-- ============================================================
-- FILE: 04_Load_Dim_Staff_Customer_Store.sql
-- MỤC ĐÍCH: ETL cho 3 bảng chiều còn lại (SCD Type 2)
--   - dw.Dim_Staff
--   - dw.Dim_Customer
--   - dw.Dim_Geography_Store
-- ============================================================

USE Sakila_DW;
GO

-- ============================================================
-- PHẦN A: LOAD Dim_Staff
-- NGUỒN: sakila.staff + sakila.store + sakila.address + sakila.city + sakila.country
-- ============================================================
PRINT 'Bắt đầu load Dim_Staff...';

IF OBJECT_ID('tempdb..#Stage_Staff', 'U') IS NOT NULL DROP TABLE #Stage_Staff;

-- === SSIS: OLE DB Source query (chạy trên sakila) ===
SELECT
    st.staff_id,
    st.first_name,
    st.last_name,
    st.first_name + ' ' + st.last_name   AS full_name,
    st.email,
    st.username,
    CAST(st.active AS BIT)               AS active,
    st.store_id,
    'Sakila Store #' + CAST(st.store_id AS VARCHAR) AS store_name,
    a.address,
    a.district,
    ci.city                              AS city_name,
    co.country                           AS country_name
INTO #Stage_Staff
FROM sakila.dbo.staff st
LEFT JOIN sakila.dbo.address a
    ON st.address_id = a.address_id
LEFT JOIN sakila.dbo.city ci
    ON a.city_id = ci.city_id
LEFT JOIN sakila.dbo.country co
    ON ci.country_id = co.country_id;

-- SCD2: Đóng bản ghi cũ nếu có thay đổi store hoặc trạng thái active
UPDATE dw.Dim_Staff
SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, updated_date = GETDATE()
WHERE is_current = 1
  AND staff_id IN (
    SELECT s.staff_id
    FROM #Stage_Staff s
    INNER JOIN dw.Dim_Staff d ON s.staff_id = d.staff_id AND d.is_current = 1
    WHERE s.store_id <> d.store_id OR s.active <> d.active
);

-- Insert bản ghi mới
INSERT INTO dw.Dim_Staff (
    staff_id, first_name, last_name, full_name,
    email, username, active, store_id, store_name,
    address, district, city_name, country_name,
    effective_date, expiry_date, is_current,
    created_date, updated_date, source_system
)
SELECT
    s.staff_id, s.first_name, s.last_name, s.full_name,
    s.email, s.username, s.active, s.store_id, s.store_name,
    s.address, s.district, s.city_name, s.country_name,
    CAST(GETDATE() AS DATE), NULL, 1,
    GETDATE(), GETDATE(), 'SAKILA'
FROM #Stage_Staff s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.Dim_Staff d
    WHERE d.staff_id = s.staff_id AND d.is_current = 1
);

-- SCD1: Cập nhật email (không cần lịch sử)
UPDATE d
SET d.email = s.email, d.updated_date = GETDATE()
FROM dw.Dim_Staff d
INNER JOIN #Stage_Staff s ON d.staff_id = s.staff_id AND d.is_current = 1
WHERE ISNULL(d.email,'') <> ISNULL(s.email,'');

PRINT 'Load Dim_Staff hoàn thành: ' + CAST((SELECT COUNT(*) FROM dw.Dim_Staff) AS VARCHAR) + ' dòng';
DROP TABLE #Stage_Staff;
GO

-- ============================================================
-- PHẦN B: LOAD Dim_Customer
-- NGUỒN: sakila.customer + sakila.address + sakila.city + sakila.country
-- ============================================================
PRINT 'Bắt đầu load Dim_Customer...';

IF OBJECT_ID('tempdb..#Stage_Customer', 'U') IS NOT NULL DROP TABLE #Stage_Customer;

-- === SSIS: OLE DB Source query ===
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.first_name + ' ' + c.last_name     AS full_name,
    c.email,
    a.address,
    ci.city,
    co.country,
    -- Tính customer_class dựa trên tổng doanh thu (Vàng top 10%, Bạc 30%, Đồng 60%)
    CASE
        WHEN total_paid.total_amount >= p90.threshold_90 THEN N'Vàng'
        WHEN total_paid.total_amount >= p70.threshold_70 THEN N'Bạc'
        ELSE N'Đồng'
    END AS customer_class
INTO #Stage_Customer
FROM sakila.dbo.customer c
LEFT JOIN sakila.dbo.address a
    ON c.address_id = a.address_id
LEFT JOIN sakila.dbo.city ci
    ON a.city_id = ci.city_id
LEFT JOIN sakila.dbo.country co
    ON ci.country_id = co.country_id
-- Tính tổng thanh toán của từng khách
LEFT JOIN (
    SELECT customer_id, SUM(amount) AS total_amount
    FROM sakila.dbo.payment
    GROUP BY customer_id
) total_paid ON c.customer_id = total_paid.customer_id
-- Tính ngưỡng phân loại
CROSS JOIN (
    SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_amount)
           OVER () AS threshold_90
    FROM (
        SELECT customer_id, SUM(amount) AS total_amount
        FROM sakila.dbo.payment
        GROUP BY customer_id
    ) x
    HAVING COUNT(*) = 1  -- workaround để lấy 1 dòng
) p90
CROSS JOIN (
    SELECT PERCENTILE_CONT(0.70) WITHIN GROUP (ORDER BY total_amount)
           OVER () AS threshold_70
    FROM (
        SELECT customer_id, SUM(amount) AS total_amount
        FROM sakila.dbo.payment
        GROUP BY customer_id
    ) x
    HAVING COUNT(*) = 1
) p70;

-- Nếu query CROSS JOIN phức tạp quá, dùng cách đơn giản hơn:
-- Xóa bảng temp và dùng cách tính percentile thủ công
IF @@ROWCOUNT = 0
BEGIN
    TRUNCATE TABLE #Stage_Customer;

    DECLARE @p90 DECIMAL(10,2), @p70 DECIMAL(10,2);

    WITH CustomerRevenue AS (
        SELECT customer_id, SUM(amount) AS total_amount
        FROM sakila.dbo.payment
        GROUP BY customer_id
    ),
    Ranked AS (
        SELECT customer_id, total_amount,
               NTILE(10) OVER (ORDER BY total_amount DESC) AS decile
        FROM CustomerRevenue
    )
    SELECT
        @p90 = MIN(total_amount) FROM Ranked WHERE decile = 1;  -- Top 10%

    WITH CustomerRevenue AS (
        SELECT customer_id, SUM(amount) AS total_amount
        FROM sakila.dbo.payment
        GROUP BY customer_id
    ),
    Ranked AS (
        SELECT customer_id, total_amount,
               NTILE(10) OVER (ORDER BY total_amount DESC) AS decile
        FROM CustomerRevenue
    )
    SELECT @p70 = MIN(total_amount) FROM Ranked WHERE decile <= 3; -- Top 30%

    INSERT INTO #Stage_Customer
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
    FROM sakila.dbo.customer c
    LEFT JOIN sakila.dbo.address a   ON c.address_id = a.address_id
    LEFT JOIN sakila.dbo.city ci     ON a.city_id = ci.city_id
    LEFT JOIN sakila.dbo.country co  ON ci.country_id = co.country_id
    LEFT JOIN (
        SELECT customer_id, SUM(amount) AS total_amount
        FROM sakila.dbo.payment
        GROUP BY customer_id
    ) rev ON c.customer_id = rev.customer_id;
END

-- SCD2: Đóng bản ghi khi địa chỉ thay đổi
UPDATE dw.Dim_Customer
SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, update_date = GETDATE()
WHERE is_current = 1
  AND customer_id IN (
    SELECT s.customer_id
    FROM #Stage_Customer s
    INNER JOIN dw.Dim_Customer d ON s.customer_id = d.customer_id AND d.is_current = 1
    WHERE ISNULL(s.city,'') <> ISNULL(d.city,'')
       OR ISNULL(s.country,'') <> ISNULL(d.country,'')
);

-- Insert bản ghi mới
INSERT INTO dw.Dim_Customer (
    customer_id, first_name, last_name, full_name, email,
    address, city, country, customer_class,
    effective_date, expiry_date, is_current,
    create_date, update_date, source_system
)
SELECT
    s.customer_id, s.first_name, s.last_name, s.full_name, s.email,
    s.address, s.city, s.country, s.customer_class,
    CAST(GETDATE() AS DATE), NULL, 1,
    GETDATE(), GETDATE(), 'SAKILA'
FROM #Stage_Customer s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.Dim_Customer d
    WHERE d.customer_id = s.customer_id AND d.is_current = 1
);

-- SCD1: Cập nhật email và customer_class (không cần lịch sử)
UPDATE d
SET
    d.email          = s.email,
    d.customer_class = s.customer_class,
    d.update_date    = GETDATE()
FROM dw.Dim_Customer d
INNER JOIN #Stage_Customer s ON d.customer_id = s.customer_id AND d.is_current = 1
WHERE ISNULL(d.email,'') <> ISNULL(s.email,'')
   OR ISNULL(d.customer_class,'') <> ISNULL(s.customer_class,'');

PRINT 'Load Dim_Customer hoàn thành: ' + CAST((SELECT COUNT(*) FROM dw.Dim_Customer) AS VARCHAR) + ' dòng';
DROP TABLE #Stage_Customer;
GO

-- ============================================================
-- PHẦN C: LOAD Dim_Geography_Store
-- NGUỒN: sakila.store + sakila.address + sakila.city + sakila.country
-- ============================================================
PRINT 'Bắt đầu load Dim_Geography_Store...';

IF OBJECT_ID('tempdb..#Stage_Store', 'U') IS NOT NULL DROP TABLE #Stage_Store;

-- === SSIS: OLE DB Source query ===
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
FROM sakila.dbo.store s
LEFT JOIN sakila.dbo.address a   ON s.address_id = a.address_id
LEFT JOIN sakila.dbo.city ci     ON a.city_id = ci.city_id
LEFT JOIN sakila.dbo.country co  ON ci.country_id = co.country_id;

-- SCD2: Đóng bản ghi khi địa chỉ cửa hàng thay đổi
UPDATE dw.Dim_Geography_Store
SET expiry_date = CAST(GETDATE() AS DATE), is_current = 0, update_date = GETDATE()
WHERE is_current = 1
  AND store_id IN (
    SELECT s.store_id
    FROM #Stage_Store s
    INNER JOIN dw.Dim_Geography_Store d ON s.store_id = d.store_id AND d.is_current = 1
    WHERE ISNULL(s.address,'') <> ISNULL(d.address,'')
       OR ISNULL(s.city,'')    <> ISNULL(d.city,'')
);

-- Insert bản ghi mới
INSERT INTO dw.Dim_Geography_Store (
    store_id, address, district, postal_code, phone,
    city_id, city, country_id, country,
    effective_date, expiry_date, is_current,
    create_date, update_date, source_system
)
SELECT
    s.store_id, s.address, s.district, s.postal_code, s.phone,
    s.city_id, s.city, s.country_id, s.country,
    CAST(GETDATE() AS DATE), NULL, 1,
    GETDATE(), GETDATE(), 'SAKILA'
FROM #Stage_Store s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.Dim_Geography_Store d
    WHERE d.store_id = s.store_id AND d.is_current = 1
);

PRINT 'Load Dim_Geography_Store hoàn thành: ' + CAST((SELECT COUNT(*) FROM dw.Dim_Geography_Store) AS VARCHAR) + ' dòng';
DROP TABLE #Stage_Store;
GO

PRINT '=== Load tất cả Dim hoàn thành ===';
GO
