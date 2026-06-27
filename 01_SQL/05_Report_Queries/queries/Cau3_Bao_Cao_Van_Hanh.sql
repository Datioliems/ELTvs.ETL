-- ============================================================
-- FILE: Cau3_Bao_Cao_Van_Hanh.sql
-- MỤC ĐÍCH: 11 câu truy vấn báo cáo vận hành (Câu 3)
-- CHẠY TRÊN: Database sakila (OLTP nguồn)
-- CÓ 2 PHIÊN BẢN: MySQL và SQL Server (đánh dấu rõ ràng)
-- ============================================================

-- ==============================================================
-- NHÓM 3.2.1: QUẢN LÝ CHO THUÊ VÀ THANH TOÁN
-- ==============================================================

-- -----------------------------------------------------------
-- QUERY 1: Doanh thu theo thể loại đĩa trong ngày
-- Đối tượng: Quản lý cửa hàng, Phòng Kinh doanh
-- Bảng dùng: category, film_category, inventory, rental, payment
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL (chạy trên MySQL Workbench):
/*
SELECT
    c.name                          AS the_loai,
    SUM(p.amount)                   AS doanh_thu,
    COUNT(DISTINCT r.rental_id)     AS so_luot_thue
FROM category c
INNER JOIN film_category fc ON c.category_id = fc.category_id
INNER JOIN inventory     i  ON fc.film_id     = i.film_id
INNER JOIN rental        r  ON i.inventory_id = r.inventory_id
INNER JOIN payment       p  ON r.rental_id    = p.rental_id
WHERE DATE(p.payment_date) = CURDATE()         -- Thay bằng ngày cụ thể, vd: '2005-07-31'
GROUP BY c.name
ORDER BY doanh_thu DESC;
*/

-- ★ PHIÊN BẢN SQL Server (chạy trên SSMS):
SELECT
    c.name                          AS the_loai,
    SUM(p.amount)                   AS doanh_thu,
    COUNT(DISTINCT r.rental_id)     AS so_luot_thue
FROM sakila.dbo.category     c
INNER JOIN sakila.dbo.film_category fc ON c.category_id  = fc.category_id
INNER JOIN sakila.dbo.inventory     i  ON fc.film_id      = i.film_id
INNER JOIN sakila.dbo.rental        r  ON i.inventory_id  = r.inventory_id
INNER JOIN sakila.dbo.payment       p  ON r.rental_id     = p.rental_id
WHERE CAST(p.payment_date AS DATE) = '2005-07-31'  -- Thay bằng ngày muốn xem
GROUP BY c.name
ORDER BY doanh_thu DESC;


-- -----------------------------------------------------------
-- QUERY 2: Thống kê số lượng giao dịch của từng chi nhánh
--          theo ngày trong tuần trong từng tháng
-- Đối tượng: Quản lý cửa hàng, Phòng Kinh doanh
-- Bảng dùng: rental, staff, store
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    s.store_id                                  AS chi_nhanh,
    MONTH(r.rental_date)                        AS thang,
    YEAR(r.rental_date)                         AS nam,
    DAYNAME(r.rental_date)                      AS ten_ngay,
    DAYOFWEEK(r.rental_date)                    AS thu_trong_tuan,
    COUNT(r.rental_id)                          AS so_giao_dich
FROM rental r
INNER JOIN staff st ON r.staff_id  = st.staff_id
INNER JOIN store s  ON st.store_id = s.store_id
GROUP BY s.store_id, YEAR(r.rental_date), MONTH(r.rental_date),
         DAYOFWEEK(r.rental_date), DAYNAME(r.rental_date)
ORDER BY chi_nhanh, nam, thang, thu_trong_tuan;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    s.store_id                                  AS chi_nhanh,
    YEAR(r.rental_date)                         AS nam,
    MONTH(r.rental_date)                        AS thang,
    DATENAME(WEEKDAY, r.rental_date)            AS ten_ngay,
    DATEPART(WEEKDAY, r.rental_date)            AS thu_trong_tuan,
    COUNT(r.rental_id)                          AS so_giao_dich
FROM sakila.dbo.rental  r
INNER JOIN sakila.dbo.staff st ON r.staff_id  = st.staff_id
INNER JOIN sakila.dbo.store s  ON st.store_id = s.store_id
GROUP BY
    s.store_id,
    YEAR(r.rental_date),
    MONTH(r.rental_date),
    DATENAME(WEEKDAY, r.rental_date),
    DATEPART(WEEKDAY, r.rental_date)
ORDER BY chi_nhanh, nam, thang, thu_trong_tuan;


-- -----------------------------------------------------------
-- QUERY 3: Thống kê doanh thu của từng cửa hàng trong ngày
-- Đối tượng: Quản lý cửa hàng, Phòng Kinh doanh
-- Bảng dùng: payment, staff, store
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    s.store_id                  AS chi_nhanh,
    DATE(p.payment_date)        AS ngay,
    SUM(p.amount)               AS tong_doanh_thu,
    COUNT(p.payment_id)         AS so_giao_dich
FROM payment p
INNER JOIN staff st ON p.staff_id  = st.staff_id
INNER JOIN store s  ON st.store_id = s.store_id
WHERE DATE(p.payment_date) = CURDATE()   -- Thay ngày cụ thể: '2005-07-31'
GROUP BY s.store_id, DATE(p.payment_date)
ORDER BY chi_nhanh;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    s.store_id                              AS chi_nhanh,
    CAST(p.payment_date AS DATE)            AS ngay,
    SUM(p.amount)                           AS tong_doanh_thu,
    COUNT(p.payment_id)                     AS so_giao_dich
FROM sakila.dbo.payment p
INNER JOIN sakila.dbo.staff st ON p.staff_id  = st.staff_id
INNER JOIN sakila.dbo.store s  ON st.store_id = s.store_id
WHERE CAST(p.payment_date AS DATE) = '2005-07-31'   -- Thay ngày cụ thể
GROUP BY s.store_id, CAST(p.payment_date AS DATE)
ORDER BY chi_nhanh;


-- ==============================================================
-- NHÓM 3.2.2: QUẢN LÝ QUAN HỆ KHÁCH HÀNG
-- ==============================================================

-- -----------------------------------------------------------
-- QUERY 4: Danh sách khách hàng đang chưa trả đĩa tại cả 2 chi nhánh
-- Đối tượng: Nhân viên quầy, Phòng Vận hành
-- Bảng dùng: customer, rental
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS ho_ten,
    c.email,
    f.title                                 AS ten_phim,
    r.rental_date                           AS ngay_thue,
    DATEDIFF(CURDATE(), r.rental_date)      AS so_ngay_da_giu,
    st.store_id                             AS chi_nhanh
FROM customer c
INNER JOIN rental    r  ON c.customer_id  = r.customer_id
INNER JOIN inventory i  ON r.inventory_id = i.inventory_id
INNER JOIN film      f  ON i.film_id      = f.film_id
INNER JOIN staff     st ON r.staff_id     = st.staff_id
WHERE r.return_date IS NULL
ORDER BY so_ngay_da_giu DESC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name        AS ho_ten,
    c.email,
    f.title                                  AS ten_phim,
    r.rental_date                            AS ngay_thue,
    DATEDIFF(DAY, r.rental_date, GETDATE())  AS so_ngay_da_giu,
    st.store_id                              AS chi_nhanh
FROM sakila.dbo.customer c
INNER JOIN sakila.dbo.rental    r  ON c.customer_id  = r.customer_id
INNER JOIN sakila.dbo.inventory i  ON r.inventory_id = i.inventory_id
INNER JOIN sakila.dbo.film      f  ON i.film_id      = f.film_id
INNER JOIN sakila.dbo.staff     st ON r.staff_id     = st.staff_id
WHERE r.return_date IS NULL
ORDER BY so_ngay_da_giu DESC;


-- -----------------------------------------------------------
-- QUERY 5: Thống kê khách hàng thuê và trả đĩa trễ (đã trả)
--          trong tuần nhất định
-- Đối tượng: Nhân viên quầy, Phòng Vận hành
-- Bảng dùng: rental, inventory, film, customer
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)              AS ho_ten,
    f.title                                              AS ten_phim,
    r.rental_date                                        AS ngay_thue,
    r.return_date                                        AS ngay_tra_thuc_te,
    f.rental_duration                                    AS so_ngay_hop_dong,
    DATEDIFF(r.return_date, r.rental_date)               AS so_ngay_thue_thuc_te,
    GREATEST(0, DATEDIFF(r.return_date, r.rental_date)
               - f.rental_duration)                      AS so_ngay_tre
FROM rental r
INNER JOIN customer  c  ON r.customer_id  = c.customer_id
INNER JOIN inventory i  ON r.inventory_id = i.inventory_id
INNER JOIN film      f  ON i.film_id      = f.film_id
WHERE r.return_date IS NOT NULL
  AND DATEDIFF(r.return_date, r.rental_date) > f.rental_duration
  -- Lọc theo tuần cụ thể: thay ngày bắt đầu và kết thúc tuần
  AND r.rental_date BETWEEN '2005-07-11' AND '2005-07-17'
ORDER BY so_ngay_tre DESC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name                        AS ho_ten,
    f.title                                                  AS ten_phim,
    r.rental_date                                            AS ngay_thue,
    r.return_date                                            AS ngay_tra_thuc_te,
    f.rental_duration                                        AS so_ngay_hop_dong,
    DATEDIFF(DAY, r.rental_date, r.return_date)              AS so_ngay_thue_thuc_te,
    CASE
        WHEN DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
        THEN DATEDIFF(DAY, r.rental_date, r.return_date) - f.rental_duration
        ELSE 0
    END                                                      AS so_ngay_tre
FROM sakila.dbo.rental r
INNER JOIN sakila.dbo.customer  c  ON r.customer_id  = c.customer_id
INNER JOIN sakila.dbo.inventory i  ON r.inventory_id = i.inventory_id
INNER JOIN sakila.dbo.film      f  ON i.film_id      = f.film_id
WHERE r.return_date IS NOT NULL
  AND DATEDIFF(DAY, r.rental_date, r.return_date) > f.rental_duration
  -- Lọc theo tuần cụ thể: thay ngày bắt đầu và kết thúc
  AND r.rental_date BETWEEN '2005-07-11' AND '2005-07-17'
ORDER BY so_ngay_tre DESC;


-- ==============================================================
-- NHÓM 3.2.3: QUẢN LÝ SẢN PHẨM
-- ==============================================================

-- -----------------------------------------------------------
-- QUERY 6: Danh sách sản phẩm (film) hot nhất hiện tại
-- Đối tượng: Nhân viên quầy, Bộ phận quản lý sản phẩm
-- Bảng dùng: film, inventory, rental
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    f.film_id,
    f.title                         AS ten_phim,
    f.rating                        AS phan_loai,
    COUNT(r.rental_id)              AS so_luot_thue
FROM film f
INNER JOIN inventory i ON f.film_id      = i.film_id
INNER JOIN rental    r ON i.inventory_id = r.inventory_id
WHERE r.rental_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)  -- 30 ngày gần nhất
GROUP BY f.film_id, f.title, f.rating
ORDER BY so_luot_thue DESC
LIMIT 10;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT TOP 10
    f.film_id,
    f.title                             AS ten_phim,
    f.rating                            AS phan_loai,
    COUNT(r.rental_id)                  AS so_luot_thue
FROM sakila.dbo.film     f
INNER JOIN sakila.dbo.inventory i ON f.film_id      = i.film_id
INNER JOIN sakila.dbo.rental    r ON i.inventory_id = r.inventory_id
-- Thay ngày bắt đầu phù hợp với dữ liệu Sakila (2005-2006)
WHERE r.rental_date >= DATEADD(DAY, -30, (SELECT MAX(rental_date) FROM sakila.dbo.rental))
GROUP BY f.film_id, f.title, f.rating
ORDER BY so_luot_thue DESC;


-- -----------------------------------------------------------
-- QUERY 7: Danh sách phim mang lại doanh thu cao nhất theo lượt thuê
-- Đối tượng: Quản lý sản phẩm, Ban vận hành cửa hàng
-- Bảng dùng: film, inventory, payment, rental
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    f.film_id,
    f.title                         AS ten_phim,
    f.rental_rate                   AS gia_thue,
    COUNT(DISTINCT r.rental_id)     AS so_luot_thue,
    SUM(p.amount)                   AS tong_doanh_thu,
    ROUND(SUM(p.amount) /
          COUNT(DISTINCT r.rental_id), 2) AS doanh_thu_moi_luot
FROM film f
INNER JOIN inventory i  ON f.film_id      = i.film_id
INNER JOIN rental    r  ON i.inventory_id = r.inventory_id
INNER JOIN payment   p  ON r.rental_id    = p.rental_id
GROUP BY f.film_id, f.title, f.rental_rate
ORDER BY tong_doanh_thu DESC
LIMIT 10;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT TOP 10
    f.film_id,
    f.title                                     AS ten_phim,
    f.rental_rate                               AS gia_thue,
    COUNT(DISTINCT r.rental_id)                 AS so_luot_thue,
    SUM(p.amount)                               AS tong_doanh_thu,
    ROUND(SUM(p.amount) /
          COUNT(DISTINCT r.rental_id), 2)       AS doanh_thu_moi_luot
FROM sakila.dbo.film     f
INNER JOIN sakila.dbo.inventory i  ON f.film_id      = i.film_id
INNER JOIN sakila.dbo.rental    r  ON i.inventory_id = r.inventory_id
INNER JOIN sakila.dbo.payment   p  ON r.rental_id    = p.rental_id
GROUP BY f.film_id, f.title, f.rental_rate
ORDER BY tong_doanh_thu DESC;


-- -----------------------------------------------------------
-- QUERY 8: Danh sách sản phẩm sắp hết hàng
-- Đối tượng: Nhân viên quầy, Bộ phận quản lý sản phẩm
-- Bảng dùng: film, inventory, rental
-- Logic: Tổng đĩa - số đĩa đang được thuê <= ngưỡng cảnh báo (2)
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    f.film_id,
    f.title                                         AS ten_phim,
    f.rating,
    COUNT(DISTINCT i.inventory_id)                  AS tong_dia,
    SUM(CASE WHEN r.return_date IS NULL THEN 1 ELSE 0 END)  AS dang_duoc_thue,
    COUNT(DISTINCT i.inventory_id) -
    SUM(CASE WHEN r.return_date IS NULL THEN 1 ELSE 0 END)  AS con_lai_trong_kho
FROM film f
INNER JOIN inventory i ON f.film_id      = i.film_id
LEFT JOIN  rental    r ON i.inventory_id = r.inventory_id
             AND r.return_date IS NULL
GROUP BY f.film_id, f.title, f.rating
HAVING con_lai_trong_kho <= 2          -- Ngưỡng cảnh báo: còn <= 2 đĩa
ORDER BY con_lai_trong_kho ASC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    f.film_id,
    f.title                                             AS ten_phim,
    f.rating,
    COUNT(DISTINCT i.inventory_id)                      AS tong_dia,
    SUM(CASE WHEN r.return_date IS NULL THEN 1 ELSE 0 END) AS dang_duoc_thue,
    COUNT(DISTINCT i.inventory_id) -
    SUM(CASE WHEN r.return_date IS NULL THEN 1 ELSE 0 END) AS con_lai_trong_kho
FROM sakila.dbo.film     f
INNER JOIN sakila.dbo.inventory i  ON f.film_id      = i.film_id
LEFT JOIN  sakila.dbo.rental    r  ON i.inventory_id = r.inventory_id
                                   AND r.return_date IS NULL
GROUP BY f.film_id, f.title, f.rating
HAVING COUNT(DISTINCT i.inventory_id) -
       SUM(CASE WHEN r.return_date IS NULL THEN 1 ELSE 0 END) <= 2
ORDER BY con_lai_trong_kho ASC;


-- ==============================================================
-- NHÓM 3.2.4: QUẢN TRỊ NHÂN SỰ
-- ==============================================================

-- -----------------------------------------------------------
-- QUERY 9: Thống kê doanh thu của từng nhân viên theo ngày
-- Đối tượng: Ban quản lý, Phòng Nhân sự
-- Bảng dùng: staff, rental, payment
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    st.staff_id,
    CONCAT(st.first_name, ' ', st.last_name)    AS ho_ten,
    st.store_id                                 AS chi_nhanh,
    DATE(p.payment_date)                        AS ngay,
    COUNT(r.rental_id)                          AS so_giao_dich,
    SUM(p.amount)                               AS doanh_thu
FROM staff st
INNER JOIN rental  r ON st.staff_id = r.staff_id
INNER JOIN payment p ON r.rental_id = p.rental_id
WHERE DATE(p.payment_date) = '2005-07-31'     -- Thay ngày cụ thể
GROUP BY st.staff_id, st.first_name, st.last_name,
         st.store_id, DATE(p.payment_date)
ORDER BY chi_nhanh, doanh_thu DESC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    st.staff_id,
    st.first_name + ' ' + st.last_name          AS ho_ten,
    st.store_id                                  AS chi_nhanh,
    CAST(p.payment_date AS DATE)                 AS ngay,
    COUNT(r.rental_id)                           AS so_giao_dich,
    SUM(p.amount)                                AS doanh_thu
FROM sakila.dbo.staff   st
INNER JOIN sakila.dbo.rental  r ON st.staff_id = r.staff_id
INNER JOIN sakila.dbo.payment p ON r.rental_id = p.rental_id
WHERE CAST(p.payment_date AS DATE) = '2005-07-31'  -- Thay ngày cụ thể
GROUP BY
    st.staff_id,
    st.first_name,
    st.last_name,
    st.store_id,
    CAST(p.payment_date AS DATE)
ORDER BY chi_nhanh, doanh_thu DESC;


-- -----------------------------------------------------------
-- QUERY 10: Thống kê doanh thu của từng nhân viên theo tháng
-- Đối tượng: Ban quản lý, Phòng Nhân sự
-- Bảng dùng: staff, rental, store, payment
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    st.staff_id,
    CONCAT(st.first_name, ' ', st.last_name)    AS ho_ten,
    s.store_id                                  AS chi_nhanh,
    YEAR(p.payment_date)                        AS nam,
    MONTH(p.payment_date)                       AS thang,
    COUNT(DISTINCT r.rental_id)                 AS so_giao_dich,
    SUM(p.amount)                               AS doanh_thu
FROM staff st
INNER JOIN store   s  ON st.store_id = s.store_id
INNER JOIN rental  r  ON st.staff_id = r.staff_id
INNER JOIN payment p  ON r.rental_id = p.rental_id
GROUP BY st.staff_id, st.first_name, st.last_name,
         s.store_id, YEAR(p.payment_date), MONTH(p.payment_date)
ORDER BY chi_nhanh, nam, thang, doanh_thu DESC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    st.staff_id,
    st.first_name + ' ' + st.last_name          AS ho_ten,
    s.store_id                                   AS chi_nhanh,
    YEAR(p.payment_date)                         AS nam,
    MONTH(p.payment_date)                        AS thang,
    COUNT(DISTINCT r.rental_id)                  AS so_giao_dich,
    SUM(p.amount)                                AS doanh_thu
FROM sakila.dbo.staff   st
INNER JOIN sakila.dbo.store   s  ON st.store_id = s.store_id
INNER JOIN sakila.dbo.rental  r  ON st.staff_id = r.staff_id
INNER JOIN sakila.dbo.payment p  ON r.rental_id = p.rental_id
GROUP BY
    st.staff_id,
    st.first_name,
    st.last_name,
    s.store_id,
    YEAR(p.payment_date),
    MONTH(p.payment_date)
ORDER BY chi_nhanh, nam, thang, doanh_thu DESC;


-- -----------------------------------------------------------
-- QUERY 11: Thống kê mỗi nhân viên đã phục vụ bao nhiêu khách hàng
-- Đối tượng: Ban quản lý, Phòng Nhân sự
-- Bảng dùng: staff, rental
-- -----------------------------------------------------------

-- ★ PHIÊN BẢN MySQL:
/*
SELECT
    st.staff_id,
    CONCAT(st.first_name, ' ', st.last_name)    AS ho_ten,
    st.store_id                                 AS chi_nhanh,
    COUNT(DISTINCT r.customer_id)               AS so_khach_hang_khac_nhau,
    COUNT(r.rental_id)                          AS tong_so_giao_dich
FROM staff st
INNER JOIN rental r ON st.staff_id = r.staff_id
GROUP BY st.staff_id, st.first_name, st.last_name, st.store_id
ORDER BY so_khach_hang_khac_nhau DESC;
*/

-- ★ PHIÊN BẢN SQL Server:
SELECT
    st.staff_id,
    st.first_name + ' ' + st.last_name          AS ho_ten,
    st.store_id                                  AS chi_nhanh,
    COUNT(DISTINCT r.customer_id)                AS so_khach_hang_khac_nhau,
    COUNT(r.rental_id)                           AS tong_so_giao_dich,
    ROUND(CAST(COUNT(r.rental_id) AS FLOAT) /
          COUNT(DISTINCT r.customer_id), 1)      AS tb_giao_dich_moi_khach
FROM sakila.dbo.staff  st
INNER JOIN sakila.dbo.rental r ON st.staff_id = r.staff_id
GROUP BY st.staff_id, st.first_name, st.last_name, st.store_id
ORDER BY so_khach_hang_khac_nhau DESC;
