-- ============================================================
-- FILE: 02_Load_Dim_Date.sql
-- MỤC ĐÍCH: Sinh tự động dữ liệu bảng Dim_Date
--           Phạm vi: 2000-01-01 đến 2030-12-31 (đủ bao phủ Sakila)
-- CHẠY TRONG: Sakila_DW
-- SSIS COMPONENT: Execute SQL Task
-- ============================================================

USE Sakila_DW;
GO

PRINT 'Bắt đầu load Dim_Date...';

-- Xóa dữ liệu cũ (trừ dòng -1 đặc biệt)
DELETE FROM dw.Dim_Date WHERE date_key > 0;

-- Khai báo biến
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

        -- day_of_week: 1=Sunday, 2=Monday ... 7=Saturday (theo SQL Server DATEPART)
        DATEPART(WEEKDAY, @Current),

        -- day_name
        DATENAME(WEEKDAY, @Current),

        -- day_of_month
        DAY(@Current),

        -- day_of_year
        DATEPART(DAYOFYEAR, @Current),

        -- week_of_year
        DATEPART(ISO_WEEK, @Current),

        -- month_of_year
        MONTH(@Current),

        -- month_name
        DATENAME(MONTH, @Current),

        -- quarter_of_year
        DATEPART(QUARTER, @Current),

        -- year
        YEAR(@Current),

        -- is_weekend: Thứ 7 (7) hoặc Chủ Nhật (1) theo SQL Server
        CASE WHEN DATEPART(WEEKDAY, @Current) IN (1, 7) THEN 1 ELSE 0 END,

        -- is_special_day: Đánh dấu các ngày lễ Việt Nam
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

PRINT 'Load Dim_Date hoàn thành: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dòng';
SELECT COUNT(*) AS TotalRows FROM dw.Dim_Date;
GO
