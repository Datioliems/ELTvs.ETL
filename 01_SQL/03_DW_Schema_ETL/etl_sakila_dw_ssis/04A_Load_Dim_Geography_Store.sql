-- ============================================================
-- FILE: 04A_Load_Dim_Geography_Store.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Trước 04B và 04C (không phụ thuộc Dim khác)
-- ============================================================

PRINT 'Bắt đầu load Dim_Geography_Store...';

IF OBJECT_ID('tempdb..#Stage_Store', 'U') IS NOT NULL
    DROP TABLE #Stage_Store;

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
LEFT JOIN sakila.dbo.city ci     ON a.city_id    = ci.city_id
LEFT JOIN sakila.dbo.country co  ON ci.country_id = co.country_id;

PRINT 'Staging Dim_Geography_Store: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- SCD2: Đóng bản ghi khi địa chỉ cửa hàng thay đổi
UPDATE dw.Dim_Geography_Store
SET
    expiry_date = CAST(GETDATE() AS DATE),
    is_current  = 0,
    update_date = GETDATE()
WHERE is_current = 1
  AND store_id IN (
    SELECT s.store_id
    FROM #Stage_Store s
    INNER JOIN dw.Dim_Geography_Store d
        ON s.store_id = d.store_id AND d.is_current = 1
    WHERE ISNULL(s.address, '') <> ISNULL(d.address, '')
       OR ISNULL(s.city, '')    <> ISNULL(d.city, '')
);

PRINT 'Đóng bản ghi cũ (SCD2): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

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

PRINT 'Insert bản ghi mới: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

SELECT COUNT(*) AS TotalRows,
       SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS CurrentRows
FROM dw.Dim_Geography_Store;

DROP TABLE #Stage_Store;
PRINT 'Load Dim_Geography_Store hoàn thành!';
