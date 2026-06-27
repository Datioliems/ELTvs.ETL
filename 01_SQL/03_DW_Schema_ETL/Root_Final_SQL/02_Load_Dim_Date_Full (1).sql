-- ============================================================
-- FILE: 02_Load_Dim_Date_Full.sql
-- MỤC ĐÍCH: Sinh tự động dữ liệu bảng Dim_Date
--           PHẦN 1: Đảm bảo dòng đặc biệt date_key = -1 tồn tại
--           PHẦN 2: Sinh các ngày từ 2000-01-01 đến 2030-12-31
-- FIX: date = '1900-01-01' thay vì NULL (cột NOT NULL)
--      IF NOT EXISTS để không bị duplicate khi chạy lại
-- CHẠY TRONG: Sakila_DW
-- SSIS: Execute SQL Task — đặt sau 00_Pre_ETL_Cleanup
-- ============================================================

USE Sakila_DW;
GO

PRINT 'Bắt đầu load Dim_Date: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- ============================================================
-- PHẦN 1: Dòng đặc biệt date_key = -1
-- Dùng '1900-01-01' cho cột date vì cột NOT NULL
-- IF NOT EXISTS để không bị lỗi duplicate khi chạy lại nhiều lần
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dw.Dim_Date WHERE date_key = -1)
BEGIN
    INSERT INTO dw.Dim_Date (
        date_key, date, day_of_week, day_name, day_of_month,
        day_of_year, week_of_year, month_of_year, month_name,
        quarter_of_year, year, is_weekend, is_special_day, special_day
    )
    VALUES (
        -1,
        '1900-01-01',   -- NOT NULL nên dùng sentinel date thay vì NULL
        0,
        N'Unknown',
        0, 0, 0, 0,
        N'Unknown',
        0, 0, 0, 0,
        N'Chua tra dia'
    );
    PRINT '+ Đã insert dòng date_key = -1';
END
ELSE
BEGIN
    PRINT '+ Dòng date_key = -1 đã tồn tại, bỏ qua';
END

-- ============================================================
-- PHẦN 2: Xóa dữ liệu ngày cũ rồi sinh lại
-- Chỉ xóa date_key > 0 để giữ dòng -1 ở trên
-- ============================================================
DELETE FROM dw.Dim_Date WHERE date_key > 0;
PRINT '+ Đã xóa dữ liệu ngày cũ';

DECLARE @StartDate DATE = '2000-01-01';
DECLARE @EndDate   DATE = '2030-12-31';
DECLARE @Current   DATE = @StartDate;

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
        CAST(FORMAT(@Current, 'yyyyMMdd') AS INT),
        @Current,
        DATEPART(WEEKDAY, @Current),
        DATENAME(WEEKDAY, @Current),
        DAY(@Current),
        DATEPART(DAYOFYEAR, @Current),
        DATEPART(ISO_WEEK, @Current),
        MONTH(@Current),
        DATENAME(MONTH, @Current),
        DATEPART(QUARTER, @Current),
        YEAR(@Current),
        CASE WHEN DATEPART(WEEKDAY, @Current) IN (1, 7) THEN 1 ELSE 0 END,
        CASE
            WHEN FORMAT(@Current, 'MM-dd') = '01-01' THEN 1
            WHEN FORMAT(@Current, 'MM-dd') = '04-30' THEN 1
            WHEN FORMAT(@Current, 'MM-dd') = '05-01' THEN 1
            WHEN FORMAT(@Current, 'MM-dd') = '09-02' THEN 1
            WHEN FORMAT(@Current, 'MM-dd') = '12-25' THEN 1
            WHEN FORMAT(@Current, 'MM-dd') = '11-24' THEN 1
            ELSE 0
        END,
        CASE
            WHEN FORMAT(@Current, 'MM-dd') = '01-01' THEN N'Tet Duong Lich'
            WHEN FORMAT(@Current, 'MM-dd') = '04-30' THEN N'Ngay Giai Phong Mien Nam'
            WHEN FORMAT(@Current, 'MM-dd') = '05-01' THEN N'Quoc Te Lao Dong'
            WHEN FORMAT(@Current, 'MM-dd') = '09-02' THEN N'Quoc Khanh'
            WHEN FORMAT(@Current, 'MM-dd') = '12-25' THEN N'Giang Sinh'
            WHEN FORMAT(@Current, 'MM-dd') = '11-24' THEN N'Ngay Van Hoa Viet Nam'
            ELSE NULL
        END
    );

    SET @Current = DATEADD(DAY, 1, @Current);
END;

PRINT 'Load Dim_Date hoàn thành';

SELECT
    COUNT(*)                                    AS tong_so_dong,
    COUNT(CASE WHEN date_key = -1  THEN 1 END)  AS dong_dac_biet,
    COUNT(CASE WHEN date_key > 0   THEN 1 END)  AS dong_ngay_thuong,
    MIN(CASE WHEN date_key > 0 THEN date END)   AS ngay_dau_tien,
    MAX(CASE WHEN date_key > 0 THEN date END)   AS ngay_cuoi_cung
FROM dw.Dim_Date;
GO
