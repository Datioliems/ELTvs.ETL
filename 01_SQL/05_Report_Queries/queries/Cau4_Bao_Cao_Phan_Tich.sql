-- ============================================================
-- FILE: Cau4_Bao_Cao_Phan_Tich.sql
-- MỤC ĐÍCH: 13 câu truy vấn báo cáo phân tích (Câu 4)
-- CHẠY TRÊN: Sakila_DW (kho dữ liệu Star Schema)
-- ============================================================

USE Sakila_DW;
GO

-- -----------------------------------------------------------
-- QUERY 1: Thống kê số lượng phim được thuê nhiều nhất
--          theo thời gian và theo thể loại
-- -----------------------------------------------------------
SELECT
    dd.year                             AS nam,
    dd.month_name                       AS thang,
    dp.category_name                    AS the_loai,
    dp.title                            AS ten_phim,
    COUNT(fs.sale_key)                  AS so_luot_thue,
    -- Xếp hạng trong từng thể loại theo từng năm
    RANK() OVER (
        PARTITION BY dd.year, dp.category_name
        ORDER BY COUNT(fs.sale_key) DESC
    )                                   AS xep_hang_trong_the_loai
FROM dw.Fact_Sale        fs
INNER JOIN dw.Dim_RentalDate  dd ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Product     dp ON fs.product_key     = dp.product_key
GROUP BY dd.year, dd.month_of_year, dd.month_name, dp.category_name, dp.title
ORDER BY dd.year, dd.month_of_year, the_loai, so_luot_thue DESC;
GO


-- -----------------------------------------------------------
-- QUERY 2: Top 5 danh mục có doanh thu nhiều nhất
--          từ năm 2005 đến năm 2006
-- -----------------------------------------------------------
SELECT TOP 5
    dp.category_name                    AS danh_muc,
    SUM(fs.amount)                      AS tong_doanh_thu,
    COUNT(fs.sale_key)                  AS tong_luot_thue,
    ROUND(SUM(fs.amount) /
          COUNT(fs.sale_key), 2)        AS doanh_thu_trung_binh_moi_luot,
    -- Tỷ lệ % trên tổng doanh thu
    ROUND(SUM(fs.amount) * 100.0 /
          SUM(SUM(fs.amount)) OVER (), 2) AS ty_le_phan_tram
FROM dw.Fact_Sale        fs
INNER JOIN dw.Dim_RentalDate  dd ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Product     dp ON fs.product_key     = dp.product_key
WHERE dd.year BETWEEN 2005 AND 2006
GROUP BY dp.category_name
ORDER BY tong_doanh_thu DESC;
GO


-- -----------------------------------------------------------
-- QUERY 3: Thống kê tình trạng trả trễ theo nhóm thời gian thuê
-- Logic: Nhóm theo số ngày thuê theo hợp đồng (1-3, 4-5, 6-7 ngày)
-- -----------------------------------------------------------
SELECT
    CASE
        WHEN fs.rental_duration_expected <= 3 THEN '1-3 ngày (ngắn)'
        WHEN fs.rental_duration_expected <= 5 THEN '4-5 ngày (trung bình)'
        ELSE '6-7 ngày (dài)'
    END                                         AS nhom_thoi_gian_thue,
    COUNT(fs.sale_key)                          AS tong_giao_dich,
    SUM(fs.is_late)                             AS so_lan_tre,
    ROUND(SUM(fs.is_late) * 100.0 /
          COUNT(fs.sale_key), 2)                AS ty_le_tre_pct,
    ROUND(AVG(CAST(fs.late_days AS FLOAT)), 1)  AS tb_so_ngay_tre,
    MAX(fs.late_days)                           AS tre_nhieu_nhat_ngay
FROM dw.Fact_Sale fs
WHERE fs.is_returned = 1   -- Chỉ tính đơn đã trả
GROUP BY
    CASE
        WHEN fs.rental_duration_expected <= 3 THEN '1-3 ngày (ngắn)'
        WHEN fs.rental_duration_expected <= 5 THEN '4-5 ngày (trung bình)'
        ELSE '6-7 ngày (dài)'
    END
ORDER BY ty_le_tre_pct DESC;
GO


-- -----------------------------------------------------------
-- QUERY 4: Thống kê doanh thu thuê phim theo cửa hàng theo từng năm
-- -----------------------------------------------------------
SELECT
    dgs.city                            AS cua_hang,
    dgs.country                         AS quoc_gia,
    dd.year                             AS nam,
    SUM(fs.amount)                      AS tong_doanh_thu,
    COUNT(fs.sale_key)                  AS so_giao_dich,
    -- So sánh với năm trước (Year-over-Year)
    SUM(fs.amount) - LAG(SUM(fs.amount), 1, 0) OVER (
        PARTITION BY dgs.store_key
        ORDER BY dd.year
    )                                   AS tang_truong_so_voi_nam_truoc,
    ROUND(
        (SUM(fs.amount) - LAG(SUM(fs.amount), 1, NULL) OVER (
            PARTITION BY dgs.store_key ORDER BY dd.year
        )) * 100.0 /
        NULLIF(LAG(SUM(fs.amount), 1, NULL) OVER (
            PARTITION BY dgs.store_key ORDER BY dd.year
        ), 0)
    , 2)                                AS pct_tang_truong
FROM dw.Fact_Sale             fs
INNER JOIN dw.Dim_RentalDate       dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Geography_Store  dgs ON fs.store_key       = dgs.store_key
GROUP BY dgs.store_key, dgs.city, dgs.country, dd.year
ORDER BY dgs.city, nam;
GO


-- -----------------------------------------------------------
-- QUERY 5: Top 10 danh mục được nhiều khách hàng yêu thích nhất
--          theo thời gian (số khách hàng KHÁC NHAU đã thuê)
-- -----------------------------------------------------------
SELECT
    dd.year                             AS nam,
    dp.category_name                    AS danh_muc,
    COUNT(DISTINCT fs.customer_key)     AS so_khach_hang_duy_nhat,
    COUNT(fs.sale_key)                  AS tong_luot_thue,
    SUM(fs.amount)                      AS tong_doanh_thu,
    -- Xếp hạng theo từng năm
    RANK() OVER (
        PARTITION BY dd.year
        ORDER BY COUNT(DISTINCT fs.customer_key) DESC
    )                                   AS xep_hang
FROM dw.Fact_Sale        fs
INNER JOIN dw.Dim_RentalDate  dd ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Product     dp ON fs.product_key     = dp.product_key
GROUP BY dd.year, dp.category_name
ORDER BY dd.year, xep_hang;
GO


-- -----------------------------------------------------------
-- QUERY 6: Thống kê phim không phát sinh giao dịch thuê
--          trong khoảng thời gian dài theo cửa hàng
-- (Factless Fact Table - phim tồn tại nhưng không được thuê)
-- -----------------------------------------------------------
SELECT
    dgs.city                            AS cua_hang,
    dp.film_id,
    dp.title                            AS ten_phim,
    dp.category_name                    AS the_loai,
    dp.rental_rate                      AS gia_thue,
    dp.inventory_count                  AS so_dia_trong_kho,
    -- Ngày giao dịch cuối cùng của phim này
    MAX(dd.date)                        AS ngay_thue_gan_nhat,
    DATEDIFF(DAY, MAX(dd.date),
             (SELECT MAX(date) FROM dw.Dim_Date WHERE date_key > 0))
                                        AS so_ngay_khong_co_giao_dich
FROM dw.Dim_Product              dp
INNER JOIN dw.Dim_Geography_Store dgs ON 1 = 1   -- Cross join để kiểm tra từng cửa hàng
LEFT JOIN  dw.Fact_Sale          fs  ON dp.product_key = fs.product_key
                                    AND fs.store_key   = dgs.store_key
LEFT JOIN  dw.Dim_RentalDate     dd  ON fs.rental_date_key = dd.rental_date_key
WHERE dp.is_current = 1 AND dgs.is_current = 1
GROUP BY dgs.store_key, dgs.city, dp.film_id, dp.title,
         dp.category_name, dp.rental_rate, dp.inventory_count
HAVING MAX(dd.date) IS NULL    -- Chưa từng được thuê
    OR DATEDIFF(DAY, MAX(dd.date),
                (SELECT MAX(date) FROM dw.Dim_Date WHERE date_key > 0)) > 30
ORDER BY dgs.city, so_ngay_khong_co_giao_dich DESC;
GO


-- -----------------------------------------------------------
-- QUERY 7: Thống kê doanh thu theo nhóm khách hàng
--          theo tháng, quý, năm (Vàng / Bạc / Đồng)
-- -----------------------------------------------------------
SELECT
    dc.customer_class                   AS hang_khach,
    dd.year                             AS nam,
    dd.quarter_of_year                  AS quy,
    dd.month_of_year                    AS thang,
    dd.month_name                       AS ten_thang,
    COUNT(DISTINCT fs.customer_key)     AS so_khach,
    COUNT(fs.sale_key)                  AS so_giao_dich,
    SUM(fs.amount)                      AS tong_doanh_thu,
    ROUND(AVG(fs.amount), 2)            AS tb_moi_giao_dich,
    -- % đóng góp trong tháng đó
    ROUND(SUM(fs.amount) * 100.0 /
          SUM(SUM(fs.amount)) OVER (
              PARTITION BY dd.year, dd.month_of_year
          ), 2)                         AS ty_le_trong_thang_pct
FROM dw.Fact_Sale        fs
INNER JOIN dw.Dim_RentalDate  dd ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Customer    dc ON fs.customer_key    = dc.customer_key
GROUP BY dc.customer_class, dd.year, dd.quarter_of_year,
         dd.month_of_year, dd.month_name
ORDER BY dd.year, dd.month_of_year, hang_khach;
GO


-- -----------------------------------------------------------
-- QUERY 8: Thống kê khu vực có nhiều khách hàng nhất
-- -----------------------------------------------------------
SELECT
    dc.country                          AS quoc_gia,
    dc.city                             AS thanh_pho,
    COUNT(DISTINCT fs.customer_key)     AS so_khach_hang,
    COUNT(fs.sale_key)                  AS tong_giao_dich,
    SUM(fs.amount)                      AS tong_doanh_thu,
    ROUND(AVG(fs.amount), 2)            AS doanh_thu_trung_binh,
    -- Xếp hạng theo số khách
    RANK() OVER (ORDER BY COUNT(DISTINCT fs.customer_key) DESC) AS xep_hang
FROM dw.Fact_Sale     fs
INNER JOIN dw.Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY dc.country, dc.city
ORDER BY so_khach_hang DESC;
GO


-- -----------------------------------------------------------
-- QUERY 9: Thống kê doanh thu theo nhân viên của 2 chi nhánh
--          trong vòng 3 năm gần nhất
-- -----------------------------------------------------------
SELECT
    dst.full_name                       AS nhan_vien,
    dst.store_name                      AS chi_nhanh,
    dd.year                             AS nam,
    COUNT(fs.sale_key)                  AS so_giao_dich,
    COUNT(DISTINCT fs.customer_key)     AS so_khach_phuc_vu,
    SUM(fs.amount)                      AS tong_doanh_thu,
    -- Tỷ lệ % trong chi nhánh từng năm
    ROUND(SUM(fs.amount) * 100.0 /
          SUM(SUM(fs.amount)) OVER (
              PARTITION BY dst.store_name, dd.year
          ), 2)                         AS ty_le_trong_chi_nhanh_pct
FROM dw.Fact_Sale       fs
INNER JOIN dw.Dim_RentalDate  dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Staff       dst ON fs.staff_key       = dst.staff_key
WHERE dd.year >= (SELECT MAX(year) FROM dw.Dim_RentalDate
                  WHERE rental_date_key IN (SELECT rental_date_key FROM dw.Fact_Sale)) - 2
GROUP BY dst.full_name, dst.store_name, dd.year
ORDER BY chi_nhanh, nam, tong_doanh_thu DESC;
GO


-- -----------------------------------------------------------
-- QUERY 10: Thống kê chi phí từ các đĩa chưa được trả
--           theo cửa hàng (rủi ro tài chính)
-- -----------------------------------------------------------
SELECT
    dgs.city                            AS cua_hang,
    dp.category_name                    AS the_loai,
    COUNT(fs.sale_key)                  AS so_dia_chua_tra,
    SUM(fs.replacement_cost)            AS tong_chi_phi_rui_ro,
    ROUND(AVG(fs.replacement_cost), 2)  AS chi_phi_trung_binh_moi_dia,
    MIN(dd.rental_date)                 AS ngay_thue_som_nhat,
    MAX(DATEDIFF(DAY, dd.rental_date,
        CAST((SELECT MAX(date) FROM dw.Dim_Date WHERE date_key > 0) AS DATE))
    )                                   AS so_ngay_chua_tra_lau_nhat
FROM dw.Fact_Sale             fs
INNER JOIN dw.Dim_RentalDate       dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Geography_Store  dgs ON fs.store_key       = dgs.store_key
INNER JOIN dw.Dim_Product          dp  ON fs.product_key     = dp.product_key
WHERE fs.is_returned = 0   -- Chỉ lấy đĩa CHƯA TRẢ
GROUP BY dgs.city, dp.category_name
ORDER BY tong_chi_phi_rui_ro DESC;
GO


-- -----------------------------------------------------------
-- QUERY 11: Doanh thu trung bình trên khách hàng (ARPU)
--           theo tháng và theo cửa hàng
-- ARPU = Average Revenue Per User
-- -----------------------------------------------------------
SELECT
    dgs.city                            AS cua_hang,
    dd.year                             AS nam,
    dd.month_of_year                    AS thang,
    dd.month_name                       AS ten_thang,
    COUNT(DISTINCT fs.customer_key)     AS so_khach_hoat_dong,
    SUM(fs.amount)                      AS tong_doanh_thu,
    ROUND(SUM(fs.amount) /
          COUNT(DISTINCT fs.customer_key), 2)   AS arpu,
    -- So sánh ARPU với tháng trước
    ROUND(SUM(fs.amount) /
          COUNT(DISTINCT fs.customer_key)
          - LAG(SUM(fs.amount) / COUNT(DISTINCT fs.customer_key), 1, NULL)
            OVER (PARTITION BY dgs.store_key ORDER BY dd.year, dd.month_of_year)
    , 2)                                AS thay_doi_arpu_so_thang_truoc
FROM dw.Fact_Sale             fs
INNER JOIN dw.Dim_RentalDate       dd  ON fs.rental_date_key = dd.rental_date_key
INNER JOIN dw.Dim_Geography_Store  dgs ON fs.store_key       = dgs.store_key
GROUP BY dgs.store_key, dgs.city, dd.year, dd.month_of_year, dd.month_name
ORDER BY dgs.city, dd.year, dd.month_of_year;
GO


-- -----------------------------------------------------------
-- QUERY 12: Tỷ lệ khách hàng không thuê phim trong hơn 30 ngày
--           (Churn Rate) theo cửa hàng
-- -----------------------------------------------------------
WITH LastRental AS (
    -- Tìm ngày thuê gần nhất của từng khách hàng tại từng cửa hàng
    SELECT
        fs.customer_key,
        fs.store_key,
        MAX(dd.date)    AS ngay_thue_cuoi
    FROM dw.Fact_Sale        fs
    INNER JOIN dw.Dim_RentalDate  dd ON fs.rental_date_key = dd.rental_date_key
    GROUP BY fs.customer_key, fs.store_key
),
MaxDate AS (
    SELECT MAX(date) AS ngay_hom_nay
    FROM dw.Dim_Date
    WHERE date_key > 0
)
SELECT
    dgs.city                            AS cua_hang,
    COUNT(lr.customer_key)              AS tong_khach,
    SUM(CASE
        WHEN DATEDIFF(DAY, lr.ngay_thue_cuoi, md.ngay_hom_nay) > 30
        THEN 1 ELSE 0
    END)                                AS khach_khong_thue_30_ngay,
    ROUND(SUM(CASE
        WHEN DATEDIFF(DAY, lr.ngay_thue_cuoi, md.ngay_hom_nay) > 30
        THEN 1.0 ELSE 0
    END) * 100.0 / COUNT(lr.customer_key), 2) AS churn_rate_pct
FROM LastRental lr
CROSS JOIN MaxDate md
INNER JOIN dw.Dim_Geography_Store dgs ON lr.store_key = dgs.store_key
GROUP BY dgs.city, dgs.store_key
ORDER BY churn_rate_pct DESC;
GO


-- -----------------------------------------------------------
-- QUERY 13: Báo cáo tăng trưởng doanh thu MoM
--           (Month-over-Month) qua từng tháng
-- -----------------------------------------------------------
WITH MonthlyRevenue AS (
    SELECT
        dgs.city                        AS cua_hang,
        dd.year                         AS nam,
        dd.month_of_year                AS thang,
        dd.month_name                   AS ten_thang,
        SUM(fs.amount)                  AS doanh_thu_thang
    FROM dw.Fact_Sale             fs
    INNER JOIN dw.Dim_RentalDate       dd  ON fs.rental_date_key = dd.rental_date_key
    INNER JOIN dw.Dim_Geography_Store  dgs ON fs.store_key       = dgs.store_key
    GROUP BY dgs.store_key, dgs.city, dd.year, dd.month_of_year, dd.month_name
)
SELECT
    cua_hang,
    nam,
    thang,
    ten_thang,
    doanh_thu_thang,
    -- Doanh thu tháng trước
    LAG(doanh_thu_thang, 1, NULL) OVER (
        PARTITION BY cua_hang ORDER BY nam, thang
    )                                   AS doanh_thu_thang_truoc,
    -- Chênh lệch tuyệt đối
    doanh_thu_thang - LAG(doanh_thu_thang, 1, 0) OVER (
        PARTITION BY cua_hang ORDER BY nam, thang
    )                                   AS chenh_lech,
    -- Tăng trưởng %
    ROUND(
        (doanh_thu_thang - LAG(doanh_thu_thang, 1, NULL) OVER (
            PARTITION BY cua_hang ORDER BY nam, thang
        )) * 100.0 /
        NULLIF(LAG(doanh_thu_thang, 1, NULL) OVER (
            PARTITION BY cua_hang ORDER BY nam, thang
        ), 0)
    , 2)                                AS tang_truong_mom_pct,
    -- Đánh giá tăng/giảm
    CASE
        WHEN doanh_thu_thang > LAG(doanh_thu_thang, 1, 0) OVER (
                PARTITION BY cua_hang ORDER BY nam, thang)
        THEN '↑ Tăng trưởng'
        WHEN doanh_thu_thang < LAG(doanh_thu_thang, 1, 0) OVER (
                PARTITION BY cua_hang ORDER BY nam, thang)
        THEN '↓ Suy giảm'
        ELSE '→ Không đổi'
    END                                 AS xu_huong
FROM MonthlyRevenue
ORDER BY cua_hang, nam, thang;
GO
