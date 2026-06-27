-- ============================================================
-- KHO DỮ LIỆU SAKILA – Script đầy đủ
-- Nguồn OLTP : sakila_origin
-- Schema KDL : dwh
-- Dựa trên   : KT_1_KHO__9_.docx
-- Phiên bản  : 2.0 (đã sửa 11 lỗi)
-- Yêu cầu    : MySQL 8.0+ (window function, EXCEPT)
-- ============================================================
-- THỨ TỰ CHẠY:
--   1. Dim_Date
--   2. Dim_Product
--   3. Dim_Customer
--   4. Dim_Geography_Store
--   5. Dim_Staff
--   6. Fact_Sale          ← phụ thuộc 5 DIM trên
--   7. Fact_Film_Coverage
--   8. Aggregate Facts    ← phụ thuộc Fact_Sale
-- ============================================================

DROP SCHEMA IF EXISTS dwh;
CREATE SCHEMA dwh DEFAULT CHARACTER SET utf8mb4;
USE dwh;

-- ============================================================
-- 1. DIM_DATE
-- Sinh tự động 2005-01-01 → 2006-12-31
-- Thêm dòng đặc biệt date_key = -1 cho return_date NULL
-- ============================================================
CREATE TABLE Dim_Date (
    date_key        INT         NOT NULL,
    date            DATE,
    day_of_week     INT,
    day_name        VARCHAR(20),
    day_of_month    INT,
    day_of_year     INT,
    week_of_year    INT,
    month_of_year   INT,
    month_name      VARCHAR(20),
    quarter_of_year INT,
    year            INT,
    is_weekend      TINYINT     DEFAULT 0,
    is_holiday      TINYINT     DEFAULT 0,
    PRIMARY KEY (date_key)
);

-- Dòng đặc biệt: khách chưa trả đĩa
INSERT INTO Dim_Date VALUES
(-1, NULL, NULL, 'Chưa trả', NULL, NULL, NULL, NULL, 'Chưa trả', NULL, NULL, 0, 0);

DROP PROCEDURE IF EXISTS fill_dim_date;
DELIMITER $$
CREATE PROCEDURE fill_dim_date()
BEGIN
    DECLARE cur DATE DEFAULT '2005-01-01';
    DECLARE end_d DATE DEFAULT '2006-12-31';
    WHILE cur <= end_d DO
        INSERT INTO Dim_Date VALUES (
            YEAR(cur)*10000 + MONTH(cur)*100 + DAY(cur),
            cur,
            DAYOFWEEK(cur),
            DAYNAME(cur),
            DAYOFMONTH(cur),
            DAYOFYEAR(cur),
            WEEK(cur, 1),
            MONTH(cur),
            MONTHNAME(cur),
            QUARTER(cur),
            YEAR(cur),
            IF(DAYOFWEEK(cur) IN (1,7), 1, 0),
            0
        );
        SET cur = DATE_ADD(cur, INTERVAL 1 DAY);
    END WHILE;
END$$
DELIMITER ;
CALL fill_dim_date();
DROP PROCEDURE IF EXISTS fill_dim_date;

-- Role-Playing Views
CREATE OR REPLACE VIEW Dim_RentalDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_ReturnDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_PaymentDate AS SELECT * FROM Dim_Date;

-- ============================================================
-- 2. DIM_PRODUCT
-- Nguồn: film + film_category + category + language + inventory
-- SCD Type 0 (tĩnh – film không thay đổi)
-- ============================================================
CREATE TABLE Dim_Product (
    product_key       INT          NOT NULL AUTO_INCREMENT,
    film_id           INT          NOT NULL,
    title             VARCHAR(255) NOT NULL,
    description       TEXT,
    release_year      YEAR,
    language_name     VARCHAR(50),
    rental_duration   INT,
    rental_rate       DECIMAL(4,2),
    length_minutes    INT,
    replacement_cost  DECIMAL(5,2),
    rating            VARCHAR(10),
    special_features  VARCHAR(255),
    category_id       INT,
    category_name     VARCHAR(25),
    inventory_count   INT          DEFAULT 0,
    is_active         TINYINT      DEFAULT 1,
    effective_date    DATE,
    created_date      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system     VARCHAR(50)  DEFAULT 'SAKILA_ORIGIN',
    PRIMARY KEY (product_key),
    INDEX idx_film_id (film_id),
    INDEX idx_category (category_name)
);

INSERT INTO Dim_Product (
    film_id, title, description, release_year,
    language_name, rental_duration, rental_rate,
    length_minutes, replacement_cost, rating, special_features,
    category_id, category_name, inventory_count,
    is_active, effective_date
)
SELECT
    f.film_id,
    f.title,
    f.description,
    f.release_year,
    l.name,
    f.rental_duration,
    f.rental_rate,
    f.length,
    f.replacement_cost,
    f.rating,
    f.special_features,
    c.category_id,
    c.name,
    COUNT(i.inventory_id),
    1,
    CURDATE()
FROM sakila_origin.film f
JOIN sakila_origin.language       l  ON f.language_id     = l.language_id
LEFT JOIN sakila_origin.film_category fc ON f.film_id     = fc.film_id
LEFT JOIN sakila_origin.category  c  ON fc.category_id    = c.category_id
LEFT JOIN sakila_origin.inventory i  ON f.film_id         = i.film_id
GROUP BY
    f.film_id, f.title, f.description, f.release_year,
    l.name, f.rental_duration, f.rental_rate,
    f.length, f.replacement_cost, f.rating, f.special_features,
    c.category_id, c.name;

-- ============================================================
-- 3. DIM_CUSTOMER
-- Nguồn: customer + address + city + country
-- SCD Type 2: is_current, effective_date, expiry_date
-- customer_class: Gold (top 10%) / Silver (10-40%) / Bronze (60%)
-- ============================================================
CREATE TABLE Dim_Customer (
    customer_key    INT          NOT NULL AUTO_INCREMENT,
    customer_id     INT          NOT NULL,
    first_name      VARCHAR(45),
    last_name       VARCHAR(45),
    full_name       VARCHAR(91),
    email           VARCHAR(50),
    address         VARCHAR(50),
    address2        VARCHAR(50),
    district        VARCHAR(20),
    postal_code     VARCHAR(10),
    phone           VARCHAR(20),
    city_id         INT,
    city_name       VARCHAR(50),
    country_id      INT,
    country_name    VARCHAR(50),
    store_id        INT,
    active          TINYINT,
    customer_class  VARCHAR(10)  DEFAULT 'Bronze',
    create_date     DATETIME,
    is_current      TINYINT      DEFAULT 1,
    effective_date  DATE,
    expiry_date     DATE,
    created_date    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system   VARCHAR(50)  DEFAULT 'SAKILA_ORIGIN',
    PRIMARY KEY (customer_key),
    INDEX idx_customer_id (customer_id),
    INDEX idx_city (city_name),
    INDEX idx_country (country_name)
);

INSERT INTO Dim_Customer (
    customer_id, first_name, last_name, full_name,
    email, address, address2, district, postal_code, phone,
    city_id, city_name, country_id, country_name,
    store_id, active, create_date, is_current, effective_date
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    CONCAT(c.first_name, ' ', c.last_name),
    c.email,
    a.address,
    a.address2,
    a.district,
    a.postal_code,
    a.phone,
    ci.city_id,
    ci.city,
    co.country_id,
    co.country,
    c.store_id,
    c.active,
    c.create_date,
    1,
    CURDATE()
FROM sakila_origin.customer c
JOIN sakila_origin.address  a  ON c.address_id  = a.address_id
JOIN sakila_origin.city     ci ON a.city_id     = ci.city_id
JOIN sakila_origin.country  co ON ci.country_id = co.country_id;

-- Cập nhật customer_class: phân vị theo tổng chi tiêu
-- Top 10% → Gold, 10-40% → Silver, còn lại → Bronze
UPDATE Dim_Customer dc
JOIN (
    SELECT
        p.customer_id,
        SUM(p.amount) AS total_spent,
        NTILE(10) OVER (ORDER BY SUM(p.amount) DESC) AS decile
    FROM sakila_origin.payment p
    GROUP BY p.customer_id
) ranked ON dc.customer_id = ranked.customer_id
SET dc.customer_class = CASE
    WHEN ranked.decile = 1       THEN 'Gold'
    WHEN ranked.decile <= 4      THEN 'Silver'
    ELSE 'Bronze'
END;

-- ============================================================
-- 4. DIM_GEOGRAPHY_STORE
-- Nguồn: store + staff(manager) + address + city + country
-- Phân cấp: Staff → Store → City → Country
-- ============================================================
CREATE TABLE Dim_Geography_Store (
    store_key       INT          NOT NULL AUTO_INCREMENT,
    store_id        INT          NOT NULL,
    store_name      VARCHAR(50),
    manager_name    VARCHAR(91),
    address         VARCHAR(50),
    address2        VARCHAR(50),
    district        VARCHAR(20),
    postal_code     VARCHAR(10),
    phone           VARCHAR(20),
    city_id         INT,
    city_name       VARCHAR(50),
    country_id      INT,
    country_name    VARCHAR(50),
    is_active       TINYINT      DEFAULT 1,
    effective_date  DATE,
    created_date    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system   VARCHAR(50)  DEFAULT 'SAKILA_ORIGIN',
    PRIMARY KEY (store_key),
    INDEX idx_store_id (store_id)
);

INSERT INTO Dim_Geography_Store (
    store_id, store_name, manager_name,
    address, address2, district, postal_code, phone,
    city_id, city_name, country_id, country_name,
    is_active, effective_date
)
SELECT
    s.store_id,
    CONCAT('Sakila Store #', s.store_id),
    CONCAT(m.first_name, ' ', m.last_name),
    a.address,
    a.address2,
    a.district,
    a.postal_code,
    a.phone,
    ci.city_id,
    ci.city,
    co.country_id,
    co.country,
    1,
    CURDATE()
FROM sakila_origin.store   s
JOIN sakila_origin.staff   m  ON s.manager_staff_id = m.staff_id
JOIN sakila_origin.address a  ON s.address_id       = a.address_id
JOIN sakila_origin.city    ci ON a.city_id          = ci.city_id
JOIN sakila_origin.country co ON ci.country_id      = co.country_id;

-- ============================================================
-- 5. DIM_STAFF
-- Nguồn: staff + store + address + city + country
-- SCD Type 2
-- ============================================================
CREATE TABLE Dim_Staff (
    staff_key       INT          NOT NULL AUTO_INCREMENT,
    staff_id        INT          NOT NULL,
    first_name      VARCHAR(45),
    last_name       VARCHAR(45),
    full_name       VARCHAR(91),
    email           VARCHAR(50),
    username        VARCHAR(16),
    active          TINYINT,
    store_id        INT,
    store_name      VARCHAR(50),
    address         VARCHAR(50),
    address2        VARCHAR(50),
    district        VARCHAR(20),
    city_name       VARCHAR(50),
    country_name    VARCHAR(50),
    is_current      TINYINT      DEFAULT 1,
    effective_date  DATE,
    expiry_date     DATE,
    created_date    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system   VARCHAR(50)  DEFAULT 'SAKILA_ORIGIN',
    PRIMARY KEY (staff_key),
    INDEX idx_staff_id (staff_id)
);

INSERT INTO Dim_Staff (
    staff_id, first_name, last_name, full_name,
    email, username, active,
    store_id, store_name,
    address, address2, district, city_name, country_name,
    is_current, effective_date
)
SELECT
    s.staff_id,
    s.first_name,
    s.last_name,
    CONCAT(s.first_name, ' ', s.last_name),
    s.email,
    s.username,
    s.active,
    s.store_id,
    CONCAT('Sakila Store #', s.store_id),
    a.address,
    a.address2,
    a.district,
    ci.city,
    co.country,
    1,
    CURDATE()
FROM sakila_origin.staff   s
JOIN sakila_origin.address a  ON s.address_id  = a.address_id
JOIN sakila_origin.city    ci ON a.city_id     = ci.city_id
JOIN sakila_origin.country co ON ci.country_id = co.country_id;

-- ============================================================
-- 6. FACT_SALE (Transaction Fact Table)
-- Nguồn: rental + payment(aggregated) + inventory + film
-- FIX #1: aggregate payment trước để tránh nhân dòng
-- FIX #2: late_days = NULL khi chưa trả (thay vì 0 giả)
-- ============================================================
CREATE TABLE Fact_Sale (
    sale_key                    INT            NOT NULL AUTO_INCREMENT,
    rental_id                   INT,
    rental_date_key             INT,
    return_date_key             INT,
    payment_date_key            INT,
    customer_key                INT,
    product_key                 INT,
    store_key                   INT,
    staff_key                   INT,
    amount                      DECIMAL(5,2),
    rental_duration_expected    INT,
    rental_duration_actual      INT,
    late_days                   INT,
    is_late                     TINYINT,
    is_returned                 TINYINT,
    replacement_cost            DECIMAL(5,2),
    last_update                 DATETIME       DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sale_key),
    INDEX idx_rental_date  (rental_date_key),
    INDEX idx_return_date  (return_date_key),
    INDEX idx_payment_date (payment_date_key),
    INDEX idx_customer     (customer_key),
    INDEX idx_product      (product_key),
    INDEX idx_store        (store_key),
    INDEX idx_staff        (staff_key),
    INDEX idx_rental_id    (rental_id)
);

INSERT INTO Fact_Sale (
    rental_id,
    rental_date_key, return_date_key, payment_date_key,
    customer_key, product_key, store_key, staff_key,
    amount,
    rental_duration_expected,
    rental_duration_actual,
    late_days,
    is_late,
    is_returned,
    replacement_cost
)
SELECT
    r.rental_id,
    COALESCE(d_r.date_key,   -1)   AS rental_date_key,
    COALESCE(d_ret.date_key, -1)   AS return_date_key,
    COALESCE(d_p.date_key,   -1)   AS payment_date_key,
    dc.customer_key,
    dp.product_key,
    dg.store_key,
    ds.staff_key,
    -- FIX #1: dùng subquery aggregate để tránh nhân dòng khi 1 rental có nhiều payment
    p_agg.total_amount             AS amount,
    f.rental_duration              AS rental_duration_expected,
    -- FIX #2: NULL khi chưa trả thay vì 0
    DATEDIFF(r.return_date, r.rental_date) AS rental_duration_actual,
    CASE
        WHEN r.return_date IS NULL THEN NULL
        ELSE GREATEST(0, DATEDIFF(r.return_date,
             DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)))
    END                            AS late_days,
    CASE
        WHEN r.return_date IS NOT NULL
         AND DATEDIFF(r.return_date,
             DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)) > 0
        THEN 1 ELSE 0
    END                            AS is_late,
    IF(r.return_date IS NOT NULL, 1, 0) AS is_returned,
    f.replacement_cost
FROM sakila_origin.rental       r
-- FIX #1: aggregate payment thành 1 dòng / rental
JOIN (
    SELECT rental_id,
           SUM(amount)        AS total_amount,
           MIN(payment_date)  AS payment_date
    FROM sakila_origin.payment
    GROUP BY rental_id
) p_agg ON r.rental_id = p_agg.rental_id
JOIN sakila_origin.inventory    i    ON r.inventory_id = i.inventory_id
JOIN sakila_origin.film         f    ON i.film_id      = f.film_id
JOIN Dim_Date                   d_r  ON DATE(r.rental_date)    = d_r.date
LEFT JOIN Dim_Date              d_ret ON DATE(r.return_date)   = d_ret.date
JOIN Dim_Date                   d_p  ON DATE(p_agg.payment_date) = d_p.date
JOIN Dim_Customer               dc   ON r.customer_id = dc.customer_id  AND dc.is_current = 1
JOIN Dim_Product                dp   ON i.film_id     = dp.film_id      AND dp.is_active  = 1
JOIN Dim_Geography_Store        dg   ON i.store_id    = dg.store_id
JOIN Dim_Staff                  ds   ON r.staff_id    = ds.staff_id     AND ds.is_current = 1;

-- ============================================================
-- 7. FACT_FILM_COVERAGE (Factless Fact – Periodic Snapshot)
-- Không có measure – chỉ ghi nhận phim nào có trong kho
-- Dùng để tìm phim không có giao dịch (EXCEPT với Fact_Sale)
-- Lưu ý: chỉ snapshot ngày đầu tiên mỗi tháng để giảm dung lượng
-- ============================================================
CREATE TABLE Fact_Film_Coverage (
    date_key     INT  NOT NULL,
    product_key  INT  NOT NULL,
    store_key    INT  NOT NULL,
    PRIMARY KEY (date_key, product_key, store_key),
    INDEX idx_product (product_key),
    INDEX idx_store   (store_key)
);

-- Snapshot ngày 1 mỗi tháng (thay vì mỗi ngày để tránh 3.3M rows)
INSERT INTO Fact_Film_Coverage (date_key, product_key, store_key)
SELECT DISTINCT
    d.date_key,
    dp.product_key,
    dg.store_key
FROM sakila_origin.inventory i
JOIN Dim_Product            dp ON i.film_id  = dp.film_id
JOIN Dim_Geography_Store    dg ON i.store_id = dg.store_id
JOIN Dim_Date               d  ON d.date_key > 0
                               AND d.day_of_month = 1
                               AND d.date BETWEEN '2005-05-01' AND '2006-08-31';

-- ============================================================
-- 8. AGGREGATE FACTS
-- ============================================================

-- ── 8a. Fact_Sale_byCustomer ─────────────────────────────────
-- Grain: date_key × customer_key × store_key
-- Câu 7 (nhóm KH Gold/Silver/Bronze), Câu 11 (churn)
CREATE TABLE Fact_Sale_byCustomer (
    date_key          INT            NOT NULL,
    customer_key      INT            NOT NULL,
    store_key         INT            NOT NULL,
    customer_class    VARCHAR(10),
    total_rentals     INT,
    total_amount      DECIMAL(10,2),
    late_count        INT,
    unreturned_count  INT,
    total_late_days   INT,
    PRIMARY KEY (date_key, customer_key, store_key)
);

INSERT INTO Fact_Sale_byCustomer
SELECT
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key,
    dc.customer_class,
    COUNT(*)                                             AS total_rentals,
    SUM(fs.amount)                                       AS total_amount,
    SUM(fs.is_late)                                      AS late_count,
    SUM(CASE WHEN fs.is_returned = 0 THEN 1 ELSE 0 END)  AS unreturned_count,
    SUM(COALESCE(fs.late_days, 0))                       AS total_late_days
FROM Fact_Sale fs
JOIN Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, fs.customer_key, fs.store_key, dc.customer_class;

-- ── 8b. Fact_Sale_byProduct ──────────────────────────────────
-- Grain: date_key × product_key × store_key
-- Câu 1 (phim thuê nhiều nhất), Câu 2 (doanh thu thể loại)
CREATE TABLE Fact_Sale_byProduct (
    date_key             INT            NOT NULL,
    product_key          INT            NOT NULL,
    store_key            INT            NOT NULL,
    total_rentals        INT,
    total_amount         DECIMAL(10,2),
    avg_duration_actual  DECIMAL(5,2),
    late_count           INT,
    PRIMARY KEY (date_key, product_key, store_key)
);

INSERT INTO Fact_Sale_byProduct
SELECT
    rental_date_key,
    product_key,
    store_key,
    COUNT(*)                         AS total_rentals,
    SUM(amount)                      AS total_amount,
    AVG(rental_duration_actual)      AS avg_duration_actual,
    SUM(is_late)                     AS late_count
FROM Fact_Sale
GROUP BY rental_date_key, product_key, store_key;

-- ── 8c. Fact_Sale_byStore ────────────────────────────────────
-- Grain: date_key × store_key
-- Câu 4 (doanh thu cửa hàng), Câu 10 (rủi ro tài chính), Câu 12 (ARPU)
CREATE TABLE Fact_Sale_byStore (
    date_key               INT            NOT NULL,
    store_key              INT            NOT NULL,
    total_rentals          INT,
    total_amount           DECIMAL(10,2),
    total_late_count       INT,
    unreturned_count       INT,
    total_replacement_cost DECIMAL(10,2),
    arpu                   DECIMAL(10,2),
    PRIMARY KEY (date_key, store_key)
);

INSERT INTO Fact_Sale_byStore
SELECT
    rental_date_key,
    store_key,
    COUNT(*)                                                     AS total_rentals,
    SUM(amount)                                                  AS total_amount,
    SUM(is_late)                                                 AS total_late_count,
    SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END)             AS unreturned_count,
    SUM(CASE WHEN is_returned = 0 THEN replacement_cost ELSE 0 END) AS total_replacement_cost,
    -- FIX: ARPU có nghĩa ở grain store vì có nhiều khách
    ROUND(SUM(amount) / NULLIF(COUNT(DISTINCT customer_key), 0), 2) AS arpu
FROM Fact_Sale
GROUP BY rental_date_key, store_key;

-- ── 8d. Fact_Sale_byStaff ────────────────────────────────────
-- Grain: date_key × staff_key × store_key
-- Câu 9 (hiệu suất nhân viên, ARPO)
CREATE TABLE Fact_Sale_byStaff (
    date_key         INT            NOT NULL,
    staff_key        INT            NOT NULL,
    store_key        INT            NOT NULL,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    total_customers  INT,
    arpo             DECIMAL(10,2),
    PRIMARY KEY (date_key, staff_key, store_key)
);

INSERT INTO Fact_Sale_byStaff
SELECT
    rental_date_key,
    staff_key,
    store_key,
    COUNT(*)                                                AS total_rentals,
    SUM(amount)                                             AS total_amount,
    COUNT(DISTINCT customer_key)                            AS total_customers,
    ROUND(SUM(amount) / NULLIF(COUNT(*), 0), 2)             AS arpo
FROM Fact_Sale
GROUP BY rental_date_key, staff_key, store_key;

-- ── 8e. Fact_Sale_byDate ─────────────────────────────────────
-- Grain: date_key × store_key
-- Câu 4 (doanh thu theo thời gian), Câu 14 (MoM growth)
-- FIX: dùng CTE để tính cumulative_amount an toàn
CREATE TABLE Fact_Sale_byDate (
    date_key           INT            NOT NULL,
    store_key          INT            NOT NULL,
    year               INT,
    month_of_year      INT,
    total_rentals      INT,
    total_amount       DECIMAL(10,2),
    total_late_count   INT,
    late_rate          DECIMAL(5,2),
    cumulative_amount  DECIMAL(12,2),
    PRIMARY KEY (date_key, store_key)
);

-- FIX #4: dùng INSERT INTO + subquery có window function
INSERT INTO Fact_Sale_byDate
WITH grouped AS (
    SELECT
        fs.rental_date_key,
        fs.store_key,
        d.year,
        d.month_of_year,
        COUNT(*)                                   AS total_rentals,
        SUM(fs.amount)                             AS total_amount,
        SUM(fs.is_late)                            AS total_late_count,
        ROUND(SUM(fs.is_late) / COUNT(*) * 100, 2) AS late_rate
    FROM Fact_Sale fs
    JOIN Dim_Date d ON fs.rental_date_key = d.date_key
    GROUP BY fs.rental_date_key, fs.store_key, d.year, d.month_of_year
)
SELECT
    rental_date_key,
    store_key,
    year,
    month_of_year,
    total_rentals,
    total_amount,
    total_late_count,
    late_rate,
    SUM(total_amount) OVER (
        PARTITION BY store_key, year
        ORDER BY rental_date_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_amount
FROM grouped;

-- ── 8f. Fact_Sale_byCategory ─────────────────────────────────
-- Grain: date_key × category_name × store_key
-- FIX #6: GROUP BY category thay vì product_key
-- Câu 2 (doanh thu thể loại), Câu 5 (thể loại yêu thích)
CREATE TABLE Fact_Sale_byCategory (
    date_key              INT            NOT NULL,
    category_name         VARCHAR(25)    NOT NULL,
    store_key             INT            NOT NULL,
    total_rentals         INT,
    unique_customers      INT,
    total_amount          DECIMAL(10,2),
    avg_amount_per_rental DECIMAL(5,2),
    arpu                  DECIMAL(10,2),
    PRIMARY KEY (date_key, category_name, store_key)
);

INSERT INTO Fact_Sale_byCategory
SELECT
    fs.rental_date_key,
    dp.category_name,
    fs.store_key,
    COUNT(*)                                                     AS total_rentals,
    COUNT(DISTINCT fs.customer_key)                              AS unique_customers,
    SUM(fs.amount)                                               AS total_amount,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(*), 0), 2)               AS avg_amount_per_rental,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(DISTINCT fs.customer_key), 0), 2) AS arpu
FROM Fact_Sale fs
JOIN Dim_Product dp ON fs.product_key = dp.product_key
GROUP BY fs.rental_date_key, dp.category_name, fs.store_key;

-- ── 8g. Fact_Sale_byRegion ───────────────────────────────────
-- Grain: date_key × city_name × country_name
-- FIX #3: grain đổi thành city/country, bỏ active_rate
-- Câu 8 (khu vực nhiều khách nhất), Câu 12 (ARPU khu vực)
CREATE TABLE Fact_Sale_byRegion (
    date_key         INT            NOT NULL,
    city_name        VARCHAR(50)    NOT NULL,
    country_name     VARCHAR(50)    NOT NULL,
    total_customers  INT,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    arpu             DECIMAL(10,2),
    PRIMARY KEY (date_key, city_name, country_name)
);

INSERT INTO Fact_Sale_byRegion
SELECT
    fs.rental_date_key,
    dc.city_name,
    dc.country_name,
    COUNT(DISTINCT fs.customer_key)                                          AS total_customers,
    COUNT(*)                                                                 AS total_rentals,
    SUM(fs.amount)                                                           AS total_amount,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(DISTINCT fs.customer_key), 0), 2)    AS arpu
FROM Fact_Sale fs
JOIN Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, dc.city_name, dc.country_name;

-- ============================================================
-- 9. KIỂM TRA SỐ DÒNG
-- ============================================================
SELECT 'Dim_Date'                AS bang,  COUNT(*) AS so_dong FROM Dim_Date
UNION ALL SELECT 'Dim_Product',            COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Customer',           COUNT(*) FROM Dim_Customer
UNION ALL SELECT 'Dim_Geography_Store',    COUNT(*) FROM Dim_Geography_Store
UNION ALL SELECT 'Dim_Staff',              COUNT(*) FROM Dim_Staff
UNION ALL SELECT 'Fact_Sale',              COUNT(*) FROM Fact_Sale
UNION ALL SELECT 'Fact_Film_Coverage',     COUNT(*) FROM Fact_Film_Coverage
UNION ALL SELECT 'Fact_Sale_byCustomer',   COUNT(*) FROM Fact_Sale_byCustomer
UNION ALL SELECT 'Fact_Sale_byProduct',    COUNT(*) FROM Fact_Sale_byProduct
UNION ALL SELECT 'Fact_Sale_byStore',      COUNT(*) FROM Fact_Sale_byStore
UNION ALL SELECT 'Fact_Sale_byStaff',      COUNT(*) FROM Fact_Sale_byStaff
UNION ALL SELECT 'Fact_Sale_byDate',       COUNT(*) FROM Fact_Sale_byDate
UNION ALL SELECT 'Fact_Sale_byCategory',   COUNT(*) FROM Fact_Sale_byCategory
UNION ALL SELECT 'Fact_Sale_byRegion',     COUNT(*) FROM Fact_Sale_byRegion;

-- ============================================================
-- 10. TRUY VẤN KIỂM TRA THEO CÂU HỎI Câu 4
-- ============================================================

-- Câu 1: Phim thuê nhiều nhất theo thể loại
SELECT
    dp.category_name,
    dp.title,
    SUM(fp.total_rentals)  AS total_rentals,
    SUM(fp.total_amount)   AS total_revenue
FROM Fact_Sale_byProduct fp
JOIN Dim_Product dp ON fp.product_key = dp.product_key
JOIN Dim_Date    d  ON fp.date_key    = d.date_key
WHERE d.year BETWEEN 2005 AND 2006
GROUP BY dp.category_name, dp.title
ORDER BY total_rentals DESC
LIMIT 10;

-- Câu 2: Top 5 thể loại doanh thu cao nhất
SELECT
    category_name,
    SUM(total_amount)   AS total_revenue,
    SUM(total_rentals)  AS total_rentals
FROM Fact_Sale_byCategory
JOIN Dim_Date d ON date_key = d.date_key
WHERE d.year BETWEEN 2005 AND 2006
GROUP BY category_name
ORDER BY total_revenue DESC
LIMIT 5;

-- Câu 4: Doanh thu cửa hàng theo năm
SELECT
    dg.store_name,
    d.year,
    SUM(fs.total_amount) AS total_revenue,
    SUM(fs.total_rentals) AS total_rentals
FROM Fact_Sale_byStore fs
JOIN Dim_Geography_Store dg ON fs.store_key = dg.store_key
JOIN Dim_Date            d  ON fs.date_key  = d.date_key
GROUP BY dg.store_name, d.year
ORDER BY d.year, total_revenue DESC;

-- Câu 5: Top 10 thể loại yêu thích (theo unique_customers)
SELECT
    category_name,
    SUM(unique_customers) AS total_unique_customers,
    SUM(total_rentals)    AS total_rentals
FROM Fact_Sale_byCategory
JOIN Dim_Date d ON date_key = d.date_key
WHERE d.year BETWEEN 2005 AND 2006
GROUP BY category_name
ORDER BY total_unique_customers DESC
LIMIT 10;

-- Câu 6: Phim không có giao dịch tháng 6/2005 tại Store #1
-- (yêu cầu MySQL 8.0.31+ cho EXCEPT)
SELECT dp.title, dp.category_name
FROM Fact_Film_Coverage fc
JOIN Dim_Product         dp ON fc.product_key = dp.product_key
JOIN Dim_Date            d  ON fc.date_key    = d.date_key
WHERE fc.store_key    = 1
  AND d.month_of_year = 6
  AND d.year          = 2005
EXCEPT
SELECT dp.title, dp.category_name
FROM Fact_Sale fs
JOIN Dim_Product dp ON fs.product_key     = dp.product_key
JOIN Dim_Date    d  ON fs.rental_date_key = d.date_key
WHERE fs.store_key    = 1
  AND d.month_of_year = 6
  AND d.year          = 2005;

-- Câu 7: Doanh thu theo nhóm khách hàng theo quý
SELECT
    d.year,
    d.quarter_of_year,
    fc.customer_class,
    SUM(fc.total_amount)   AS total_revenue,
    SUM(fc.total_rentals)  AS total_rentals
FROM Fact_Sale_byCustomer fc
JOIN Dim_Date d ON fc.date_key = d.date_key
GROUP BY d.year, d.quarter_of_year, fc.customer_class
ORDER BY d.year, d.quarter_of_year;

-- Câu 8: Khu vực có nhiều khách nhất
SELECT
    country_name,
    city_name,
    SUM(total_customers) AS total_customers,
    SUM(total_amount)    AS total_revenue,
    ROUND(AVG(arpu), 2)  AS avg_arpu
FROM Fact_Sale_byRegion
GROUP BY country_name, city_name
ORDER BY total_customers DESC
LIMIT 20;

-- Câu 9: Doanh thu nhân viên theo tháng
SELECT
    ds.full_name,
    dg.store_name,
    d.year,
    d.month_of_year,
    SUM(fs.total_amount)  AS total_revenue,
    SUM(fs.total_rentals) AS total_rentals,
    ROUND(AVG(fs.arpo), 2) AS avg_arpo
FROM Fact_Sale_byStaff fs
JOIN Dim_Staff           ds ON fs.staff_key = ds.staff_key
JOIN Dim_Geography_Store dg ON fs.store_key = dg.store_key
JOIN Dim_Date            d  ON fs.date_key  = d.date_key
GROUP BY ds.full_name, dg.store_name, d.year, d.month_of_year
ORDER BY d.year, d.month_of_year;

-- Câu 10: Chi phí đĩa chưa trả theo cửa hàng
SELECT
    dg.store_name,
    SUM(fs.unreturned_count)       AS so_dia_chua_tra,
    SUM(fs.total_replacement_cost) AS tong_rui_ro_tai_chinh
FROM Fact_Sale_byStore fs
JOIN Dim_Geography_Store dg ON fs.store_key = dg.store_key
GROUP BY dg.store_name
ORDER BY tong_rui_ro_tai_chinh DESC;

-- Câu 12 (ARPU theo cửa hàng theo tháng)
SELECT
    dg.store_name,
    d.year,
    d.month_of_year,
    ROUND(AVG(fs.arpu), 2) AS avg_arpu
FROM Fact_Sale_byStore fs
JOIN Dim_Geography_Store dg ON fs.store_key = dg.store_key
JOIN Dim_Date            d  ON fs.date_key  = d.date_key
GROUP BY dg.store_name, d.year, d.month_of_year
ORDER BY d.year, d.month_of_year;
