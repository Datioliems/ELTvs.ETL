-- ============================================================
-- FILE: 03_Load_Dim_Product.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- ============================================================

PRINT 'Bắt đầu load Dim_Product...';

-- BƯỚC 1: Tạo bảng staging
IF OBJECT_ID('tempdb..#Stage_Product', 'U') IS NOT NULL
    DROP TABLE #Stage_Product;

SELECT
    f.film_id,
    f.title,
    f.description,
    CAST(f.release_year AS SMALLINT)       AS release_year,
    f.language_id,
    ISNULL(l.name, 'Unknown')              AS language_name,
    f.rental_duration,
    f.rental_rate,
    f.length,
    f.replacement_cost,
    f.rating,
    fc.category_id,
    c.name                                 AS category_name,
    ISNULL(inv.inventory_count, 0)         AS inventory_count
INTO #Stage_Product
FROM sakila.dbo.film f
LEFT JOIN sakila.dbo.language l
    ON f.language_id = l.language_id
LEFT JOIN sakila.dbo.film_category fc
    ON f.film_id = fc.film_id
LEFT JOIN sakila.dbo.category c
    ON fc.category_id = c.category_id
LEFT JOIN (
    SELECT film_id, COUNT(*) AS inventory_count
    FROM sakila.dbo.inventory
    GROUP BY film_id
) inv ON f.film_id = inv.film_id;

PRINT 'Staging Dim_Product: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- BƯỚC 2: SCD Type 2 - Đóng bản ghi cũ khi có thay đổi
UPDATE dw.Dim_Product
SET
    expiry_date  = CAST(GETDATE() AS DATE),
    is_current   = 0,
    updated_date = GETDATE()
WHERE is_current = 1
  AND film_id IN (
    SELECT s.film_id
    FROM #Stage_Product s
    INNER JOIN dw.Dim_Product d
        ON s.film_id = d.film_id AND d.is_current = 1
    WHERE
        s.rental_rate      <> d.rental_rate
     OR s.category_name    <> ISNULL(d.category_name, '')
     OR s.rental_duration  <> ISNULL(d.rental_duration, 0)
     OR s.replacement_cost <> ISNULL(d.replacement_cost, 0)
     OR s.rating           <> ISNULL(d.rating, '')
     OR s.inventory_count  <> ISNULL(d.inventory_count, 0)
);

PRINT 'Đóng bản ghi cũ (SCD2): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- BƯỚC 3: Insert bản ghi mới
INSERT INTO dw.Dim_Product (
    film_id, title, description, release_year,
    language_id, language_name, rental_duration, rental_rate,
    length, replacement_cost, rating,
    category_id, category_name, inventory_count,
    effective_date, expiry_date, is_current,
    created_date, updated_date, source_system
)
SELECT
    s.film_id,
    s.title,
    s.description,
    s.release_year,
    s.language_id,
    s.language_name,
    s.rental_duration,
    s.rental_rate,
    s.length,
    s.replacement_cost,
    s.rating,
    s.category_id,
    s.category_name,
    s.inventory_count,
    CAST(GETDATE() AS DATE),
    NULL,
    1,
    GETDATE(),
    GETDATE(),
    'SAKILA'
FROM #Stage_Product s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.Dim_Product d
    WHERE d.film_id = s.film_id AND d.is_current = 1
);

PRINT 'Insert bản ghi mới vào Dim_Product: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- BƯỚC 4: SCD Type 1 - Cập nhật cột ít quan trọng (không cần lịch sử)
UPDATE d
SET
    d.title         = s.title,
    d.description   = s.description,
    d.language_name = s.language_name,
    d.length        = s.length,
    d.updated_date  = GETDATE()
FROM dw.Dim_Product d
INNER JOIN #Stage_Product s
    ON d.film_id = s.film_id AND d.is_current = 1
WHERE d.title  <> s.title
   OR d.length <> ISNULL(s.length, 0);

PRINT 'Cập nhật SCD1 Dim_Product: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

SELECT
    COUNT(*)                                        AS TotalRows,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS CurrentRows,
    SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) AS HistoricalRows
FROM dw.Dim_Product;

DROP TABLE #Stage_Product;
PRINT 'Load Dim_Product hoàn thành!';
