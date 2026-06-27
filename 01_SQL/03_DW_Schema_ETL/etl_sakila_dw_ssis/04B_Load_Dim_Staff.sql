-- ============================================================
-- FILE: 04B_Load_Dim_Staff.sql  [SSIS-READY]
-- PASTE VÀO: Execute SQL Task - Connection: DestSakilaDW
-- THỨ TỰ CHẠY: Sau 04A
-- ============================================================

PRINT 'Bắt đầu load Dim_Staff...';

IF OBJECT_ID('tempdb..#Stage_Staff', 'U') IS NOT NULL
    DROP TABLE #Stage_Staff;

SELECT
    st.staff_id,
    st.first_name,
    st.last_name,
    st.first_name + ' ' + st.last_name        AS full_name,
    st.email,
    st.username,
    CAST(st.active AS BIT)                    AS active,
    st.store_id,
    'Sakila Store #' + CAST(st.store_id AS VARCHAR) AS store_name,
    a.address,
    a.district,
    ci.city                                   AS city_name,
    co.country                                AS country_name
INTO #Stage_Staff
FROM sakila.dbo.staff st
LEFT JOIN sakila.dbo.address a   ON st.address_id = a.address_id
LEFT JOIN sakila.dbo.city ci     ON a.city_id     = ci.city_id
LEFT JOIN sakila.dbo.country co  ON ci.country_id = co.country_id;

PRINT 'Staging Dim_Staff: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- SCD2: Đóng bản ghi khi nhân viên đổi chi nhánh hoặc trạng thái
UPDATE dw.Dim_Staff
SET
    expiry_date = CAST(GETDATE() AS DATE),
    is_current  = 0,
    updated_date = GETDATE()
WHERE is_current = 1
  AND staff_id IN (
    SELECT s.staff_id
    FROM #Stage_Staff s
    INNER JOIN dw.Dim_Staff d
        ON s.staff_id = d.staff_id AND d.is_current = 1
    WHERE s.store_id <> d.store_id
       OR s.active   <> d.active
);

PRINT 'Đóng bản ghi cũ (SCD2): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

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

PRINT 'Insert bản ghi mới: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

-- SCD1: Cập nhật email (không cần lịch sử)
UPDATE d
SET
    d.email      = s.email,
    d.updated_date = GETDATE()
FROM dw.Dim_Staff d
INNER JOIN #Stage_Staff s ON d.staff_id = s.staff_id AND d.is_current = 1
WHERE ISNULL(d.email, '') <> ISNULL(s.email, '');

PRINT 'Cập nhật SCD1 (email): ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';

SELECT COUNT(*) AS TotalRows,
       SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS CurrentRows
FROM dw.Dim_Staff;

DROP TABLE #Stage_Staff;
PRINT 'Load Dim_Staff hoàn thành!';
