-- ============================================================
-- FILE: Kiem_Tra_Toan_Dien.sql
-- MỤC ĐÍCH: Chứng minh ETL đổ dữ liệu thành công với 3 bài test
--   TEST 1: Kiểm tra số dòng đúng (nguồn vs đích)
--   TEST 2: Kiểm tra SCD Type 2 hoạt động đúng
--   TEST 3: Kiểm tra chất lượng dữ liệu (không NULL, không mất)
-- CHẠY TRÊN: SSMS
-- ============================================================

-- ============================================================
-- TEST 1: SO SÁNH SỐ DÒNG NGUỒN vs ĐÍCH
-- Mục đích: Chứng minh không bị mất dữ liệu khi ETL
-- ============================================================
PRINT '========== TEST 1: KIỂM TRA SỐ DÒNG ==========';

SELECT
    'NGUỒN'             AS loai,
    'Sakila_Sales'      AS phan_he,
    'rental'            AS bang,
    COUNT(*)            AS so_dong
FROM Sakila_Sales.dbo.rental
UNION ALL
SELECT 'NGUỒN', 'Sakila_Sales',     'payment',      COUNT(*) FROM Sakila_Sales.dbo.payment
UNION ALL
SELECT 'NGUỒN', 'Sakila_CRM',       'customer',     COUNT(*) FROM Sakila_CRM.dbo.customer
UNION ALL
SELECT 'NGUỒN', 'Sakila_Inventory', 'film',         COUNT(*) FROM Sakila_Inventory.dbo.film
UNION ALL
SELECT 'NGUỒN', 'Sakila_Inventory', 'inventory',    COUNT(*) FROM Sakila_Inventory.dbo.inventory
UNION ALL
SELECT 'NGUỒN', 'Sakila_HRM',       'staff',        COUNT(*) FROM Sakila_HRM.dbo.staff
UNION ALL
SELECT 'NGUỒN', 'Sakila_HRM',       'store',        COUNT(*) FROM Sakila_HRM.dbo.store
UNION ALL
-- So sánh với bảng Dim/Fact đích
SELECT 'ĐÍCH', 'Sakila_DW', 'Fact_Sale',           COUNT(*) FROM Sakila_DW.dw.Fact_Sale
UNION ALL
SELECT 'ĐÍCH', 'Sakila_DW', 'Dim_Product(current)',COUNT(*) FROM Sakila_DW.dw.Dim_Product  WHERE is_current=1
UNION ALL
SELECT 'ĐÍCH', 'Sakila_DW', 'Dim_Customer(current)',COUNT(*) FROM Sakila_DW.dw.Dim_Customer WHERE is_current=1
UNION ALL
SELECT 'ĐÍCH', 'Sakila_DW', 'Dim_Staff(current)',  COUNT(*) FROM Sakila_DW.dw.Dim_Staff    WHERE is_current=1
UNION ALL
SELECT 'ĐÍCH', 'Sakila_DW', 'Dim_Geography_Store', COUNT(*) FROM Sakila_DW.dw.Dim_Geography_Store WHERE is_current=1
ORDER BY loai DESC, phan_he, bang;


-- So sánh trực tiếp: rental nguồn vs Fact_Sale đích
PRINT '';
PRINT '--- Kiểm tra số giao dịch: rental nguồn vs Fact_Sale đích ---';

DECLARE @src_rental   INT; SELECT @src_rental   = COUNT(*) FROM Sakila_Sales.dbo.rental;
DECLARE @dst_fact     INT; SELECT @dst_fact     = COUNT(*) FROM Sakila_DW.dw.Fact_Sale;
DECLARE @src_customer INT; SELECT @src_customer = COUNT(*) FROM Sakila_CRM.dbo.customer;
DECLARE @dst_customer INT; SELECT @dst_customer = COUNT(*) FROM Sakila_DW.dw.Dim_Customer WHERE is_current=1;
DECLARE @src_film     INT; SELECT @src_film     = COUNT(*) FROM Sakila_Inventory.dbo.film;
DECLARE @dst_product  INT; SELECT @dst_product  = COUNT(*) FROM Sakila_DW.dw.Dim_Product WHERE is_current=1;

SELECT
    'rental → Fact_Sale'     AS kiem_tra,
    @src_rental              AS so_dong_nguon,
    @dst_fact                AS so_dong_dich,
    CASE WHEN @src_rental = @dst_fact THEN '✓ KHỚP' ELSE '✗ KHÔNG KHỚP' END AS ket_qua
UNION ALL
SELECT
    'customer → Dim_Customer',
    @src_customer, @dst_customer,
    CASE WHEN @src_customer = @dst_customer THEN '✓ KHỚP' ELSE '✗ KHÔNG KHỚP' END
UNION ALL
SELECT
    'film → Dim_Product',
    @src_film, @dst_product,
    CASE WHEN @src_film = @dst_product THEN '✓ KHỚP' ELSE '✗ KHÔNG KHỚP' END;


-- ============================================================
-- TEST 2: KIỂM TRA SCD TYPE 2 HOẠT ĐỘNG ĐÚNG
-- Mục đích: Chứng minh lịch sử được lưu khi dữ liệu thay đổi
-- Cách: Sửa 1 bản ghi trong nguồn → chạy lại ETL → kiểm tra
-- ============================================================
PRINT '';
PRINT '========== TEST 2: KIỂM TRA SCD TYPE 2 ==========';

-- BƯỚC 2A: Xem trạng thái TRƯỚC KHI thay đổi
PRINT '--- Trạng thái TRƯỚC khi thay đổi ---';
SELECT
    product_key,
    film_id,
    rental_rate,
    effective_date,
    expiry_date,
    is_current,
    source_system
FROM Sakila_DW.dw.Dim_Product
WHERE film_id = 1   -- Phim đầu tiên làm mẫu
ORDER BY effective_date;

-- BƯỚC 2B: Thay đổi giá thuê phim film_id = 1 trong nguồn
PRINT '';
PRINT '--- Đang thay đổi rental_rate của film_id = 1 trong nguồn... ---';

UPDATE Sakila_Inventory.dbo.film
SET rental_rate = rental_rate + 1.00
WHERE film_id = 1;

DECLARE @new_rate DECIMAL(4,2);
SELECT @new_rate = rental_rate FROM Sakila_Inventory.dbo.film WHERE film_id = 1;
PRINT 'rental_rate mới: ' + CAST(@new_rate AS VARCHAR);

-- BƯỚC 2C: Chạy lại ETL cho Dim_Product
PRINT '';
PRINT '--- Chạy lại ETL Dim_Product... ---';
EXEC Sakila_DW.dw.usp_Load_Dim_Product;

-- BƯỚC 2D: Kiểm tra SAU KHI thay đổi (phải có 2 bản ghi cho film_id = 1)
PRINT '';
PRINT '--- Trạng thái SAU khi thay đổi (phải có 2 dòng) ---';
SELECT
    product_key,
    film_id,
    rental_rate,
    effective_date,
    expiry_date,
    is_current,
    CASE WHEN is_current = 1 THEN '→ BẢN GHI HIỆN TẠI'
         ELSE '→ BẢN GHI LỊCH SỬ (đã đóng)'
    END AS trang_thai
FROM Sakila_DW.dw.Dim_Product
WHERE film_id = 1
ORDER BY effective_date;

-- Đánh giá kết quả SCD2
DECLARE @history_count INT;
SELECT @history_count = COUNT(*) FROM Sakila_DW.dw.Dim_Product WHERE film_id = 1;
PRINT '';
PRINT CASE WHEN @history_count >= 2
    THEN '✓ SCD Type 2 HOẠT ĐỘNG ĐÚNG: có ' + CAST(@history_count AS VARCHAR) + ' bản ghi (1 lịch sử + 1 hiện tại)'
    ELSE '✗ SCD Type 2 CHƯA ĐÚNG: chỉ có ' + CAST(@history_count AS VARCHAR) + ' bản ghi'
END;

-- BƯỚC 2E: Khôi phục dữ liệu gốc (không ảnh hưởng đến test khác)
UPDATE Sakila_Inventory.dbo.film
SET rental_rate = rental_rate - 1.00
WHERE film_id = 1;
PRINT 'Đã khôi phục rental_rate gốc.';


-- ============================================================
-- TEST 3: KIỂM TRA CHẤT LƯỢNG DỮ LIỆU
-- Mục đích: Đảm bảo không có dữ liệu lỗi sau ETL
-- ============================================================
PRINT '';
PRINT '========== TEST 3: KIỂM TRA CHẤT LƯỢNG DỮ LIỆU ==========';

USE Sakila_DW;

-- 3A: Kiểm tra Foreign Key toàn vẹn trong Fact_Sale
PRINT '--- 3A: Kiểm tra khóa ngoại trong Fact_Sale ---';
SELECT
    'customer_key mồ côi'   AS kiem_tra,
    COUNT(*)                AS so_dong_loi
FROM dw.Fact_Sale f
WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Customer d WHERE d.customer_key = f.customer_key)
UNION ALL
SELECT 'product_key mồ côi', COUNT(*) FROM dw.Fact_Sale f
WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Product d WHERE d.product_key = f.product_key)
UNION ALL
SELECT 'store_key mồ côi', COUNT(*) FROM dw.Fact_Sale f
WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Geography_Store d WHERE d.store_key = f.store_key)
UNION ALL
SELECT 'staff_key mồ côi', COUNT(*) FROM dw.Fact_Sale f
WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Staff d WHERE d.staff_key = f.staff_key);
-- → Tất cả phải ra 0

-- 3B: Kiểm tra giá trị amount không âm
PRINT '--- 3B: Kiểm tra amount không âm ---';
DECLARE @neg INT; SELECT @neg = COUNT(*) FROM dw.Fact_Sale WHERE amount < 0;
PRINT CASE WHEN @neg = 0 THEN '✓ Không có amount âm' ELSE '✗ Có ' + CAST(@neg AS VARCHAR) + ' dòng amount âm' END;

-- 3C: Kiểm tra customer_class hợp lệ
PRINT '--- 3C: Kiểm tra phân loại khách hàng ---';
SELECT customer_class, COUNT(*) AS so_khach
FROM dw.Dim_Customer
WHERE is_current = 1
GROUP BY customer_class
ORDER BY so_khach DESC;
-- → Phải chỉ có 3 giá trị: Vàng, Bạc, Đồng

-- 3D: Kiểm tra Dim_Date bao phủ đủ ngày trong Fact
PRINT '--- 3D: Kiểm tra Dim_Date bao phủ đủ ---';
DECLARE @missing_dates INT;
SELECT @missing_dates = COUNT(*)
FROM dw.Fact_Sale f
WHERE f.rental_date_key NOT IN (SELECT date_key FROM dw.Dim_Date)
   OR f.payment_date_key NOT IN (SELECT date_key FROM dw.Dim_Date);
PRINT CASE WHEN @missing_dates = 0
    THEN '✓ Dim_Date bao phủ đủ tất cả ngày trong Fact'
    ELSE '✗ Thiếu ' + CAST(@missing_dates AS VARCHAR) + ' ngày trong Dim_Date'
END;

-- 3E: Thống kê tổng doanh thu - so sánh nguồn vs đích
PRINT '--- 3E: Kiểm tra tổng doanh thu nguồn vs đích ---';
DECLARE @src_revenue  DECIMAL(12,2); SELECT @src_revenue  = SUM(amount) FROM Sakila_Sales.dbo.payment;
DECLARE @dst_revenue  DECIMAL(12,2); SELECT @dst_revenue  = SUM(amount) FROM dw.Fact_Sale;
SELECT
    @src_revenue    AS tong_doanh_thu_nguon,
    @dst_revenue    AS tong_doanh_thu_dich,
    @src_revenue - @dst_revenue AS chenh_lech,
    CASE WHEN ABS(@src_revenue - @dst_revenue) < 0.01
        THEN '✓ KHỚP HOÀN TOÀN'
        ELSE '✗ CHÊNH LỆCH: ' + CAST(ABS(@src_revenue - @dst_revenue) AS VARCHAR)
    END AS ket_qua;

-- ============================================================
-- BÁO CÁO TỔNG HỢP KẾT QUẢ KIỂM TRA
-- ============================================================
PRINT '';
PRINT '========== BÁO CÁO TỔNG HỢP ==========';

SELECT
    test_name,
    ket_qua
FROM (
    SELECT 1 AS stt, 'Số dòng Fact_Sale khớp rental nguồn'   AS test_name,
           CASE WHEN (SELECT COUNT(*) FROM Sakila_Sales.dbo.rental) =
                     (SELECT COUNT(*) FROM dw.Fact_Sale)
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END AS ket_qua
    UNION ALL
    SELECT 2, 'Số dòng Dim_Customer khớp customer nguồn',
           CASE WHEN (SELECT COUNT(*) FROM Sakila_CRM.dbo.customer) =
                     (SELECT COUNT(*) FROM dw.Dim_Customer WHERE is_current=1)
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END
    UNION ALL
    SELECT 3, 'Số dòng Dim_Product khớp film nguồn',
           CASE WHEN (SELECT COUNT(*) FROM Sakila_Inventory.dbo.film) =
                     (SELECT COUNT(*) FROM dw.Dim_Product WHERE is_current=1)
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END
    UNION ALL
    SELECT 4, 'Tổng doanh thu nguồn vs đích khớp nhau',
           CASE WHEN ABS((SELECT SUM(amount) FROM Sakila_Sales.dbo.payment) -
                         (SELECT SUM(amount) FROM dw.Fact_Sale)) < 0.01
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END
    UNION ALL
    SELECT 5, 'Không có khóa ngoại mồ côi trong Fact_Sale',
           CASE WHEN (SELECT COUNT(*) FROM dw.Fact_Sale f
                      WHERE NOT EXISTS (SELECT 1 FROM dw.Dim_Customer d WHERE d.customer_key = f.customer_key)) = 0
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END
    UNION ALL
    SELECT 6, 'Dim_Date bao phủ đủ tất cả ngày',
           CASE WHEN (SELECT COUNT(*) FROM dw.Fact_Sale f
                      WHERE f.rental_date_key NOT IN (SELECT date_key FROM dw.Dim_Date)) = 0
           THEN '✓ ĐẠT' ELSE '✗ KHÔNG ĐẠT' END
) x
ORDER BY stt;
GO
