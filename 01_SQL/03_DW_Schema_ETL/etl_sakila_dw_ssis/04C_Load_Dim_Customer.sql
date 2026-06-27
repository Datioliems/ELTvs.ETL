-- ============================================================
-- FILE: 04C_Load_Dim_Customer.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Sau 04A và 04B
-- ============================================================

PRINT 'Bắt đầu load Dim_Customer...';

IF OBJECT_ID('tempdb..#Stage_Customer', 'U') IS NOT NULL
    DROP TABLE #Stage_Customer;

-- Tính ngưỡng phân loại khách hàng Vàng/Bạc/Đồng
DECLARE @p90 DECIMAL(10,2);
DECLARE @p70 DECIMAL(10,2);

-- Top 10% doanh thu -> Vàng
SELECT @p90 = MIN(total_amount)
FROM (
    SELECT customer_id, SUM(amount) AS total_amount,
           NTILE(10) OVER (ORDER BY SUM(amount) DESC) AS decile
    FROM sakila.dbo.payment
    GROUP BY customer_id
) x
WHERE decile = 1;

-- Top 30% doanh thu -> Bạc
SELECT @p70 = MIN(total_amount)
FROM (
    SELECT customer_id, SUM(amount) AS total_amount,
           NTILE(10) OVER (ORDER BY SUM(amount) DESC) AS decile
    FROM sakila.dbo.payment
    GROUP BY customer_id
) x
WHERE decile <= 3;

-- Staging: join tất cả bảng nguồn + tính customer_class
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.first_name + ' ' + c.last_name   AS full_name,
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
FROM sakila.dbo.customer c
LEFT JOIN sakila.dbo.address a   ON c.address_id  = a.address_id
LEFT JOIN sakila.dbo.city ci     ON a.city_id      = ci.city_id
LEFT JOIN sakila.dbo.country co  ON ci.country_id  = co.country_id
LEFT JOIN (
    SELECT customer_id, SUM(amount) AS total_amount
    FROM sakila.dbo.payment
    GROUP BY customer_id
) rev ON c.customer_id = rev.customer_id;

PRINT 'Staging Dim_Customer: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- SCD2: Đóng bản ghi khi địa chỉ thay đổi
UPDATE dw.Dim_Customer
SET
    expiry_date = CAST(GETDATE() AS DATE),
    is_current  = 0,
    update_date = GETDATE()
WHERE is_current = 1
  AND customer_id IN (
    SELECT s.customer_id
    FROM #Stage_Customer s
    INNER JOIN dw.Dim_Customer d
        ON s.customer_id = d.customer_id AND d.is_current = 1
    WHERE ISNULL(s.city,    '') <> ISNULL(d.city,    '')
       OR ISNULL(s.country, '') <> ISNULL(d.country, '')
);

PRINT 'Đóng bản ghi cũ (SCD2): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

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

PRINT 'Insert bản ghi mới: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- SCD1: Cập nhật email và customer_class (không cần lịch sử)
UPDATE d
SET
    d.email          = s.email,
    d.customer_class = s.customer_class,
    d.update_date    = GETDATE()
FROM dw.Dim_Customer d
INNER JOIN #Stage_Customer s ON d.customer_id = s.customer_id AND d.is_current = 1
WHERE ISNULL(d.email,          '') <> ISNULL(s.email,          '')
   OR ISNULL(d.customer_class, '') <> ISNULL(s.customer_class, '');

PRINT 'Cập nhật SCD1 (email, customer_class): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

SELECT COUNT(*) AS TotalRows,
       SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS CurrentRows
FROM dw.Dim_Customer;

DROP TABLE #Stage_Customer;
PRINT 'Load Dim_Customer hoàn thành!';
