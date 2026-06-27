-- ============================================================
-- KHO DỮ LIỆU SAKILA – Script tạo và nạp dữ liệu đầy đủ
-- Dựa trên thiết kế trong tài liệu KT_1_KHO__4_.docx
-- Chạy trên MySQL/MariaDB với bộ dữ liệu Sakila đã có sẵn
-- ============================================================
-- THỨ TỰ CHẠY:
--   1. Tạo schema dwh
--   2. Tạo & nạp Dim_Date
--   3. Tạo & nạp Dim_Product
--   4. Tạo & nạp Dim_Customer
--   5. Tạo & nạp Dim_Geography_Store
--   6. Tạo & nạp Dim_Staff
--   7. Tạo & nạp Fact_Sale
--   8. Tạo & nạp Fact_Film_Coverage
--   9. Tạo & nạp các Aggregate Facts
-- ============================================================

-- Thay 'sakila' bằng tên schema OLTP nếu khác
SET @oltp = 'sakila';

DROP SCHEMA IF EXISTS dwh;
CREATE SCHEMA dwh DEFAULT CHARACTER SET utf8mb4;
USE dwh;

-- ============================================================
-- 1. DIM_DATE
-- ============================================================
CREATE TABLE Dim_Date (
    date_key        INT          NOT NULL,   -- YYYYMMDD, -1 = chưa trả
    date            DATE,
    day_of_week     INT,                     -- 1=Sun ... 7=Sat
    day_name        VARCHAR(20),
    day_of_month    INT,
    day_of_year     INT,
    week_of_year    INT,
    month_of_year   INT,
    month_name      VARCHAR(20),
    quarter_of_year INT,
    year            INT,
    is_weekend      TINYINT,                 -- 1=cuối tuần
    is_holiday      TINYINT DEFAULT 0,       -- mở rộng sau
    PRIMARY KEY (date_key)
);

-- Dòng đặc biệt cho return_date chưa có
INSERT INTO Dim_Date VALUES (-1, NULL, NULL, 'Chưa trả', NULL, NULL, NULL, NULL, 'Chưa trả', NULL, NULL, NULL, 0);

-- Sinh tự động toàn bộ ngày trong range dữ liệu Sakila (2005-01-01 → 2006-12-31)
DROP PROCEDURE IF EXISTS fill_dim_date;
DELIMITER $$
CREATE PROCEDURE fill_dim_date()
BEGIN
    DECLARE cur DATE DEFAULT '2005-01-01';
    DECLARE end_date DATE DEFAULT '2006-12-31';
    WHILE cur <= end_date DO
        INSERT INTO Dim_Date (
            date_key, date,
            day_of_week, day_name,
            day_of_month, day_of_year,
            week_of_year, month_of_year, month_name,
            quarter_of_year, year,
            is_weekend, is_holiday
        ) VALUES (
            DATE_FORMAT(cur, '%Y%m%d') + 0,
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
DROP PROCEDURE fill_dim_date;

-- ============================================================
-- 2. DIM_PRODUCT
-- Nguồn: film + film_category + category + language + inventory
-- ============================================================
CREATE TABLE Dim_Product (
    product_key           INT          NOT NULL AUTO_INCREMENT,
    film_id               INT          NOT NULL,    -- natural key
    title                 VARCHAR(255) NOT NULL,
    description           TEXT,
    release_year          YEAR,
    language_name         VARCHAR(50),
    original_language     VARCHAR(50),
    rental_duration       INT,
    rental_rate           DECIMAL(4,2),
    length_minutes        INT,
    replacement_cost      DECIMAL(5,2),
    rating                VARCHAR(10),
    special_features      VARCHAR(255),
    category_id           INT,
    category_name         VARCHAR(25),
    inventory_count       INT,
    is_active             TINYINT      DEFAULT 1,
    effective_date        DATE,
    expiry_date           DATE,
    created_date          DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system         VARCHAR(50)  DEFAULT 'SAKILA_OLTP',
    PRIMARY KEY (product_key),
    INDEX idx_film_id (film_id)
);

INSERT INTO Dim_Product (
    film_id, title, description, release_year,
    language_name, original_language,
    rental_duration, rental_rate, length_minutes,
    replacement_cost, rating, special_features,
    category_id, category_name, inventory_count,
    is_active, effective_date
)
SELECT
    f.film_id,
    f.title,
    f.description,
    f.release_year,
    l.name                                      AS language_name,
    ol.name                                     AS original_language,
    f.rental_duration,
    f.rental_rate,
    f.length,
    f.replacement_cost,
    f.rating,
    f.special_features,
    c.category_id,
    c.name                                      AS category_name,
    COUNT(i.inventory_id)                       AS inventory_count,
    1,
    CURDATE()
FROM sakila.film f
JOIN sakila.language l
    ON f.language_id = l.language_id
LEFT JOIN sakila.language ol
    ON f.original_language_id = ol.language_id
LEFT JOIN sakila.film_category fc
    ON f.film_id = fc.film_id
LEFT JOIN sakila.category c
    ON fc.category_id = c.category_id
LEFT JOIN sakila.inventory i
    ON f.film_id = i.film_id
GROUP BY
    f.film_id, f.title, f.description, f.release_year,
    l.name, ol.name, f.rental_duration, f.rental_rate,
    f.length, f.replacement_cost, f.rating, f.special_features,
    c.category_id, c.name;

-- ============================================================
-- 3. DIM_CUSTOMER
-- Nguồn: customer + address + city + country
-- ============================================================
CREATE TABLE Dim_Customer (
    customer_key     INT          NOT NULL AUTO_INCREMENT,
    customer_id      INT          NOT NULL,    -- natural key
    first_name       VARCHAR(45),
    last_name        VARCHAR(45),
    full_name        VARCHAR(91),
    email            VARCHAR(50),
    address          VARCHAR(50),
    address2         VARCHAR(50),
    district         VARCHAR(20),
    postal_code      VARCHAR(10),
    phone            VARCHAR(20),
    city_id          INT,
    city_name        VARCHAR(50),
    country_id       INT,
    country_name     VARCHAR(50),
    store_id         INT,
    active           TINYINT,
    -- customer_class tính sau khi có Fact (Gold/Silver/Bronze)
    customer_class   VARCHAR(10)  DEFAULT 'Bronze',
    create_date      DATETIME,
    is_current       TINYINT      DEFAULT 1,
    effective_date   DATE,
    expiry_date      DATE,
    created_date     DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system    VARCHAR(50)  DEFAULT 'SAKILA_OLTP',
    PRIMARY KEY (customer_key),
    INDEX idx_customer_id (customer_id)
);

INSERT INTO Dim_Customer (
    customer_id, first_name, last_name, full_name,
    email, address, address2, district, postal_code, phone,
    city_id, city_name, country_id, country_name,
    store_id, active, create_date,
    is_current, effective_date
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
FROM sakila.customer c
JOIN sakila.address  a  ON c.address_id  = a.address_id
JOIN sakila.city     ci ON a.city_id     = ci.city_id
JOIN sakila.country  co ON ci.country_id = co.country_id;

-- Cập nhật customer_class dựa trên tổng chi tiêu
-- Top 10% → Gold, 10-40% → Silver, còn lại → Bronze
UPDATE Dim_Customer dc
JOIN (
    SELECT
        c.customer_id,
        SUM(p.amount) AS total_spent,
        NTILE(10) OVER (ORDER BY SUM(p.amount) DESC) AS decile
    FROM sakila.customer c
    JOIN sakila.payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
) ranked ON dc.customer_id = ranked.customer_id
SET dc.customer_class = CASE
    WHEN ranked.decile = 1  THEN 'Gold'
    WHEN ranked.decile <= 4 THEN 'Silver'
    ELSE 'Bronze'
END;

-- ============================================================
-- 4. DIM_GEOGRAPHY_STORE
-- Nguồn: store + staff(manager) + address + city + country
-- ============================================================
CREATE TABLE Dim_Geography_Store (
    store_key       INT          NOT NULL AUTO_INCREMENT,
    store_id        INT          NOT NULL,    -- natural key
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
    expiry_date     DATE,
    created_date    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    source_system   VARCHAR(50)  DEFAULT 'SAKILA_OLTP',
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
FROM sakila.store    s
JOIN sakila.staff    m  ON s.manager_staff_id = m.staff_id
JOIN sakila.address  a  ON s.address_id       = a.address_id
JOIN sakila.city     ci ON a.city_id          = ci.city_id
JOIN sakila.country  co ON ci.country_id      = co.country_id;

-- ============================================================
-- 5. DIM_STAFF
-- Nguồn: staff + store + address + city + country
-- SCD Type 2: is_current, effective_date, expiry_date
-- ============================================================
CREATE TABLE Dim_Staff (
    staff_key       INT          NOT NULL AUTO_INCREMENT,
    staff_id        INT          NOT NULL,    -- natural key
    first_name      VARCHAR(45),
    last_name        VARCHAR(45),
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
    updated_date    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    source_system   VARCHAR(50)  DEFAULT 'SAKILA_OLTP',
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
FROM sakila.staff    s
JOIN sakila.address  a  ON s.address_id  = a.address_id
JOIN sakila.city     ci ON a.city_id     = ci.city_id
JOIN sakila.country  co ON ci.country_id = co.country_id;

-- ============================================================
-- 6. FACT_SALE (Transaction Fact)
-- Nguồn: rental + payment + inventory + film
-- ============================================================
CREATE TABLE Fact_Sale (
    sale_key                    INT            NOT NULL AUTO_INCREMENT,
    rental_id                   INT,           -- Degenerate Dimension
    rental_date_key             INT,           -- FK → Dim_Date (Role 1)
    return_date_key             INT,           -- FK → Dim_Date (Role 2), -1 = chưa trả
    payment_date_key            INT,           -- FK → Dim_Date (Role 3)
    customer_key                INT,           -- FK → Dim_Customer
    product_key                 INT,           -- FK → Dim_Product
    store_key                   INT,           -- FK → Dim_Geography_Store
    staff_key                   INT,           -- FK → Dim_Staff
    -- Measures
    amount                      DECIMAL(5,2),  -- Fully Additive
    rental_duration_expected    INT,           -- Fully Additive
    rental_duration_actual      INT,           -- Semi-Additive
    late_days                   INT,           -- Semi-Additive
    is_late                     TINYINT,       -- Non-Additive Flag
    is_returned                 TINYINT,       -- Non-Additive Flag
    replacement_cost            DECIMAL(5,2),  -- Fully Additive
    -- Audit
    last_update                 DATETIME       DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sale_key),
    INDEX idx_rental_date  (rental_date_key),
    INDEX idx_return_date  (return_date_key),
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
    amount, rental_duration_expected, rental_duration_actual,
    late_days, is_late, is_returned, replacement_cost
)
SELECT
    r.rental_id,
    -- rental_date_key: lookup Dim_Date
    COALESCE(d_r.date_key,  -1)                                         AS rental_date_key,
    -- return_date_key: -1 nếu chưa trả
    COALESCE(d_ret.date_key, -1)                                        AS return_date_key,
    -- payment_date_key
    COALESCE(d_p.date_key,  -1)                                         AS payment_date_key,
    -- surrogate keys từ DIM
    dc.customer_key,
    dp.product_key,
    dg.store_key,
    ds.staff_key,
    -- measures
    p.amount,
    f.rental_duration                                                    AS rental_duration_expected,
    DATEDIFF(r.return_date, r.rental_date)                               AS rental_duration_actual,
    GREATEST(0, COALESCE(
        DATEDIFF(r.return_date,
            DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)),
        0))                                                              AS late_days,
    CASE WHEN r.return_date IS NOT NULL
          AND DATEDIFF(r.return_date,
              DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)) > 0
         THEN 1 ELSE 0 END                                              AS is_late,
    IF(r.return_date IS NOT NULL, 1, 0)                                  AS is_returned,
    f.replacement_cost
FROM sakila.rental          r
JOIN sakila.payment         p   ON r.rental_id    = p.rental_id
JOIN sakila.inventory       i   ON r.inventory_id = i.inventory_id
JOIN sakila.film            f   ON i.film_id      = f.film_id
-- lookup surrogate keys
JOIN Dim_Date               d_r  ON DATE(r.rental_date)  = d_r.date
LEFT JOIN Dim_Date          d_ret ON DATE(r.return_date) = d_ret.date
JOIN Dim_Date               d_p  ON DATE(p.payment_date) = d_p.date
JOIN Dim_Customer           dc   ON r.customer_id = dc.customer_id  AND dc.is_current = 1
JOIN Dim_Product            dp   ON i.film_id     = dp.film_id      AND dp.is_active  = 1
JOIN Dim_Geography_Store    dg   ON i.store_id    = dg.store_id
JOIN Dim_Staff              ds   ON r.staff_id    = ds.staff_id     AND ds.is_current = 1;

-- Role-Playing Views
CREATE OR REPLACE VIEW Dim_RentalDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_ReturnDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_PaymentDate AS SELECT * FROM Dim_Date;

-- ============================================================
-- 7. FACT_FILM_COVERAGE (Factless Fact – Periodic Snapshot)
-- Nguồn: inventory + sakila data
-- Chạy mỗi ngày, snapshot tồn kho
-- ============================================================
CREATE TABLE Fact_Film_Coverage (
    date_key     INT  NOT NULL,   -- FK → Dim_Date
    product_key  INT  NOT NULL,   -- FK → Dim_Product
    store_key    INT  NOT NULL,   -- FK → Dim_Geography_Store
    -- Không có measure – đây là Factless Fact
    PRIMARY KEY (date_key, product_key, store_key),
    INDEX idx_product (product_key),
    INDEX idx_store   (store_key)
);

-- Nạp một lần cho toàn bộ range dữ liệu Sakila
-- (Trong thực tế: chạy hàng ngày với date = CURDATE())
INSERT INTO Fact_Film_Coverage (date_key, product_key, store_key)
SELECT DISTINCT
    d.date_key,
    dp.product_key,
    dg.store_key
FROM sakila.inventory i
JOIN Dim_Product            dp ON i.film_id  = dp.film_id
JOIN Dim_Geography_Store    dg ON i.store_id = dg.store_id
CROSS JOIN Dim_Date         d
WHERE d.date BETWEEN '2005-05-01' AND '2006-08-31'  -- range thực tế của Sakila
  AND d.date_key > 0;  -- loại trừ dòng -1

-- ============================================================
-- 8. AGGREGATE FACTS – tính từ Fact_Sale
-- ============================================================

-- 8a. Fact_Sale_byCustomer
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
    arpu              DECIMAL(10,2),
    PRIMARY KEY (date_key, customer_key, store_key)
);

INSERT INTO Fact_Sale_byCustomer
SELECT
    rental_date_key                             AS date_key,
    customer_key,
    store_key,
    dc.customer_class,
    COUNT(*)                                    AS total_rentals,
    SUM(fs.amount)                              AS total_amount,
    SUM(fs.is_late)                             AS late_count,
    SUM(CASE WHEN fs.is_returned = 0 THEN 1 ELSE 0 END) AS unreturned_count,
    SUM(fs.late_days)                           AS total_late_days,
    SUM(fs.amount) / COUNT(DISTINCT fs.customer_key) AS arpu
FROM Fact_Sale fs
JOIN Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, fs.customer_key, fs.store_key, dc.customer_class;

-- 8b. Fact_Sale_byProduct
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
    COUNT(*)                                    AS total_rentals,
    SUM(amount)                                 AS total_amount,
    AVG(rental_duration_actual)                 AS avg_duration_actual,
    SUM(is_late)                                AS late_count
FROM Fact_Sale
GROUP BY rental_date_key, product_key, store_key;

-- 8c. Fact_Sale_byStore
CREATE TABLE Fact_Sale_byStore (
    date_key               INT            NOT NULL,
    store_key              INT            NOT NULL,
    total_rentals          INT,
    total_amount           DECIMAL(10,2),
    total_late_count       INT,
    unreturned_count       INT,
    total_replacement_risk DECIMAL(10,2),
    PRIMARY KEY (date_key, store_key)
);

INSERT INTO Fact_Sale_byStore
SELECT
    rental_date_key,
    store_key,
    COUNT(*)                                                    AS total_rentals,
    SUM(amount)                                                 AS total_amount,
    SUM(is_late)                                                AS total_late_count,
    SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END)            AS unreturned_count,
    SUM(CASE WHEN is_returned = 0 THEN replacement_cost ELSE 0 END) AS total_replacement_risk
FROM Fact_Sale
GROUP BY rental_date_key, store_key;

-- 8d. Fact_Sale_byStaff
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
    COUNT(*)                                    AS total_rentals,
    SUM(amount)                                 AS total_amount,
    COUNT(DISTINCT customer_key)                AS total_customers,
    SUM(amount) / COUNT(*)                      AS arpo
FROM Fact_Sale
GROUP BY rental_date_key, staff_key, store_key;

-- 8e. Fact_Sale_byDate
CREATE TABLE Fact_Sale_byDate (
    date_key           INT            NOT NULL,
    store_key          INT            NOT NULL,
    total_rentals      INT,
    total_amount       DECIMAL(10,2),
    total_late_count   INT,
    late_rate          DECIMAL(5,2),
    cumulative_amount  DECIMAL(12,2),
    PRIMARY KEY (date_key, store_key)
);

INSERT INTO Fact_Sale_byDate
SELECT
    rental_date_key                              AS date_key,
    store_key,
    COUNT(*)                                     AS total_rentals,
    SUM(amount)                                  AS total_amount,
    SUM(is_late)                                 AS total_late_count,
    ROUND(SUM(is_late) / COUNT(*) * 100, 2)      AS late_rate,
    -- cumulative_amount: tính lũy kế trong cùng năm
    SUM(SUM(amount)) OVER (
        PARTITION BY store_key, YEAR(d.date)
        ORDER BY rental_date_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                            AS cumulative_amount
FROM Fact_Sale fs
JOIN Dim_Date d ON fs.rental_date_key = d.date_key
GROUP BY rental_date_key, store_key, YEAR(d.date);

-- 8f. Fact_Sale_byCategory
CREATE TABLE Fact_Sale_byCategory (
    date_key              INT            NOT NULL,
    product_key           INT            NOT NULL,
    store_key             INT            NOT NULL,
    total_rentals         INT,
    total_amount          DECIMAL(10,2),
    unique_customers      INT,
    avg_amount_per_rental DECIMAL(5,2),
    PRIMARY KEY (date_key, product_key, store_key)
);

INSERT INTO Fact_Sale_byCategory
SELECT
    fs.rental_date_key,
    fs.product_key,
    fs.store_key,
    COUNT(*)                            AS total_rentals,
    SUM(fs.amount)                      AS total_amount,
    COUNT(DISTINCT fs.customer_key)     AS unique_customers,
    SUM(fs.amount) / COUNT(*)           AS avg_amount_per_rental
FROM Fact_Sale fs
GROUP BY fs.rental_date_key, fs.product_key, fs.store_key;

-- 8g. Fact_Sale_byRegion
CREATE TABLE Fact_Sale_byRegion (
    date_key         INT            NOT NULL,
    customer_key     INT            NOT NULL,
    total_customers  INT,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    arpu             DECIMAL(10,2),
    active_rate      DECIMAL(5,2),
    PRIMARY KEY (date_key, customer_key)
);

INSERT INTO Fact_Sale_byRegion
SELECT
    fs.rental_date_key,
    fs.customer_key,
    COUNT(DISTINCT fs.customer_key)          AS total_customers,
    COUNT(*)                                  AS total_rentals,
    SUM(fs.amount)                            AS total_amount,
    SUM(fs.amount) / COUNT(DISTINCT fs.customer_key) AS arpu,
    -- active_rate: % KH có GD / tổng KH đăng ký cùng city
    ROUND(
        COUNT(DISTINCT fs.customer_key) * 100.0 /
        NULLIF((
            SELECT COUNT(*) FROM Dim_Customer dc2
            WHERE dc2.city_name = dc.city_name AND dc2.is_current = 1
        ), 0)
    , 2)                                      AS active_rate
FROM Fact_Sale fs
JOIN Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, fs.customer_key;

-- ============================================================
-- 9. KIỂM TRA – đếm số dòng các bảng
-- ============================================================
SELECT 'Dim_Date'              AS table_name, COUNT(*) AS row_count FROM Dim_Date
UNION ALL SELECT 'Dim_Product',             COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Customer',            COUNT(*) FROM Dim_Customer
UNION ALL SELECT 'Dim_Geography_Store',     COUNT(*) FROM Dim_Geography_Store
UNION ALL SELECT 'Dim_Staff',               COUNT(*) FROM Dim_Staff
UNION ALL SELECT 'Fact_Sale',               COUNT(*) FROM Fact_Sale
UNION ALL SELECT 'Fact_Film_Coverage',      COUNT(*) FROM Fact_Film_Coverage
UNION ALL SELECT 'Fact_Sale_byCustomer',    COUNT(*) FROM Fact_Sale_byCustomer
UNION ALL SELECT 'Fact_Sale_byProduct',     COUNT(*) FROM Fact_Sale_byProduct
UNION ALL SELECT 'Fact_Sale_byStore',       COUNT(*) FROM Fact_Sale_byStore
UNION ALL SELECT 'Fact_Sale_byStaff',       COUNT(*) FROM Fact_Sale_byStaff
UNION ALL SELECT 'Fact_Sale_byDate',        COUNT(*) FROM Fact_Sale_byDate
UNION ALL SELECT 'Fact_Sale_byCategory',    COUNT(*) FROM Fact_Sale_byCategory
UNION ALL SELECT 'Fact_Sale_byRegion',      COUNT(*) FROM Fact_Sale_byRegion;

-- ============================================================
-- 10. VÍ DỤ TRUY VẤN KIỂM TRA
-- ============================================================

-- Câu 2: Top 5 thể loại doanh thu cao nhất 2005-2006
SELECT
    dp.category_name,
    SUM(fs.total_amount)    AS total_revenue,
    SUM(fs.total_rentals)   AS total_rentals
FROM Fact_Sale_byProduct fs
JOIN Dim_Product dp ON fs.product_key = dp.product_key
JOIN Dim_Date    d  ON fs.date_key    = d.date_key
WHERE d.year BETWEEN 2005 AND 2006
GROUP BY dp.category_name
ORDER BY total_revenue DESC
LIMIT 5;

-- Câu 4: Doanh thu theo cửa hàng theo năm
SELECT
    dg.store_name,
    d.year,
    SUM(fs.total_amount) AS total_revenue
FROM Fact_Sale_byStore fs
JOIN Dim_Geography_Store dg ON fs.store_key  = dg.store_key
JOIN Dim_Date            d  ON fs.date_key   = d.date_key
GROUP BY dg.store_name, d.year
ORDER BY d.year, total_revenue DESC;

-- Câu 6: Phim không có giao dịch tháng 6/2005 tại store 1
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
    SUM(fc.total_rentals)  AS total_rentals,
    ROUND(AVG(fc.arpu), 2) AS avg_arpu
FROM Fact_Sale_byCustomer fc
JOIN Dim_Date d ON fc.date_key = d.date_key
GROUP BY d.year, d.quarter_of_year, fc.customer_class
ORDER BY d.year, d.quarter_of_year, total_revenue DESC;

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
ORDER BY d.year, d.month_of_year, total_revenue DESC;
