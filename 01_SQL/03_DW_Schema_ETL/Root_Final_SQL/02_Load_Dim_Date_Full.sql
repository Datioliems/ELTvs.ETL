-- ============================================================
-- FILE: 02_Load_Dim_Date_Full.sql
-- MỤC ĐÍCH: Khởi tạo đầy đủ bảng Dim_Date gồm:
--   PHẦN 1 — Dòng đặc biệt date_key = -1 (Chưa trả đĩa)
--   PHẦN 2 — Sinh tự động các ngày từ 2000-01-01 đến 2030-12-31
-- CHẠY TRONG: Sakila_DW
-- SSIS: Dán toàn bộ file này vào 1 Execute SQL Task duy nhất
--       Đặt trước tất cả các DFT trong Control Flow
-- ============================================================

USE Sakila_DW;
GO

-- ============================================================
-- PHẦN 1: INSERT dòng đặc biệt date_key = -1
-- Dùng cho return_date_key khi khách chưa trả đĩa (return_date IS NULL)
-- Cần có TRƯỚC khi load Fact_Sale để Lookup không bị lỗi FK
-- ============================================================

PRINT 'Bắt đầu PHẦN 1: Kiểm tra và insert dòng đặc biệt date_key = -1...';

IF NOT EXISTS (SELECT 1 FROM dw.Dim_Date WHERE date_key = -1)
BEGIN
    INSERT INTO dw.Dim_Date (
        date_key,
        date,
        day_of_week,
        day_name,
        day_of_month,
        day_of_year,
        week_of_year,
        month_of_year,
        month_name,
        quarter_of_year,
        year,
        is_weekend,
        is_special_day,
        special_day
    )
    VALUES (
        -1,         -- date_key đặc biệt
        NULL,       -- không có ngày thực tế
        0,          -- day_of_week = 0 (không xác định)
        'N/A',      -- day_name
        0,          -- day_of_month
        0,          -- day_of_year
        0,          -- week_of_year
        0,          -- month_of_year
        'N/A',      -- month_name
        0,          -- quarter_of_year
        0,          -- year
        0,          -- is_weekend
        0,          -- is_special_day
        N'Chưa trả đĩa'  -- special_day — mô tả nghiệp vụ
    );
    PRINT '  → Đã insert dòng date_key = -1 (Chưa trả đĩa).';
END
ELSE
BEGIN
    PRINT '  → Dòng date_key = -1 đã tồn tại, bỏ qua insert.';
END

GO

-- ============================================================
-- PHẦN 2: Sinh tự động các ngày từ 2000-01-01 đến 2030-12-31
-- Lưu ý: Chỉ xóa date_key > 0 để giữ nguyên dòng -1 ở PHẦN 1
-- ============================================================

PRINT '';
PRINT 'Bắt đầu PHẦN 2: Sinh dữ liệu Dim_Date 2000-01-01 → 2030-12-31...';

-- Xóa dữ liệu ngày cũ (giữ lại dòng -1)
DELETE FROM dw.Dim_Date WHERE date_key > 0;
PRINT '  → Đã xóa dữ liệu cũ (date_key > 0).';

-- Khai báo biến vòng lặp
DECLARE @StartDate DATE = '2000-01-01';
DECLARE @EndDate   DATE = '2030-12-31';
DECLARE @Current   DATE = @StartDate;

-- Vòng lặp sinh từng ngày
WHILE @Current <= @EndDate
BEGIN
    INSERT INTO dw.Dim_Date (
        date_key,
        date,
        day_of_week,
        day_name,
        day_of_month,
        day_of_year,
        week_of_year,
        month_of_year,
        month_name,
        quarter_of_year,
        year,
        is_weekend,
        is_special_day,
        special_day
    )
    VALUES (
        -- date_key: định dạng YYYYMMDD
        CAST(FORMAT(@Current, 'yyyyMMdd') AS INT),

        -- date
        @Current,

        -- day_of_week: 1=Sunday, 2=Monday ... 7=Saturday
        DATEPART(WEEKDAY, @Current),

        -- day_name
        DATENAME(WEEKDAY, @Current),

        -- day_of_month
        DAY(@Current),

        -- day_of_year
        DATEPART(DAYOFYEAR, @Current),

        -- week_of_year (ISO)
        DATEPART(ISO_WEEK, @Current),

        -- month_of_year
        MONTH(@Current),

        -- month_name
        DATENAME(MONTH, @Current),

        -- quarter_of_year
        DATEPART(QUARTER, @Current),

        -- year
        YEAR(@Current),

        -- is_weekend: Thứ 7 (7) hoặc Chủ Nhật (1)
        CASE WHEN DATEPART(WEEKDAY, @Current) IN (1, 7) THEN 1 ELSE 0 END,

        -- is_special_day: Ngày lễ Việt Nam
        CASE
            WHEN FORMAT(@Current, 'MM-dd') = '01-01' THEN 1  -- Tết Dương lịch
            WHEN FORMAT(@Current, 'MM-dd') = '04-30' THEN 1  -- Giải phóng miền Nam
            WHEN FORMAT(@Current, 'MM-dd') = '05-01' THEN 1  -- Quốc tế Lao động
            WHEN FORMAT(@Current, 'MM-dd') = '09-02' THEN 1  -- Quốc khánh
            WHEN FORMAT(@Current, 'MM-dd') = '12-25' THEN 1  -- Giáng sinh
            WHEN FORMAT(@Current, 'MM-dd') = '11-24' THEN 1  -- Ngày Văn Hóa Việt Nam
            ELSE 0
        END,

        -- special_day
        CASE
            WHEN FORMAT(@Current, 'MM-dd') = '01-01' THEN N'Tết Dương Lịch'
            WHEN FORMAT(@Current, 'MM-dd') = '04-30' THEN N'Ngày Giải Phóng Miền Nam'
            WHEN FORMAT(@Current, 'MM-dd') = '05-01' THEN N'Quốc Tế Lao Động'
            WHEN FORMAT(@Current, 'MM-dd') = '09-02' THEN N'Quốc Khánh'
            WHEN FORMAT(@Current, 'MM-dd') = '12-25' THEN N'Giáng Sinh'
            WHEN FORMAT(@Current, 'MM-dd') = '11-24' THEN N'Ngày Văn Hóa Việt Nam'
            ELSE NULL
        END
    );

    SET @Current = DATEADD(DAY, 1, @Current);
END;

PRINT 'PHẦN 2 hoàn thành.';

-- Kiểm tra kết quả tổng thể
PRINT '';
PRINT '=== Kiểm tra kết quả ===';
SELECT
    COUNT(*)                                        AS tong_so_dong,
    COUNT(CASE WHEN date_key = -1 THEN 1 END)       AS dong_dac_biet,
    COUNT(CASE WHEN date_key > 0  THEN 1 END)       AS dong_ngay_thuong,
    MIN(CASE WHEN date_key > 0 THEN date END)       AS ngay_dau_tien,
    MAX(CASE WHEN date_key > 0 THEN date END)       AS ngay_cuoi_cung,
    COUNT(CASE WHEN is_special_day = 1 THEN 1 END)  AS so_ngay_le
FROM dw.Dim_Date;
GO
