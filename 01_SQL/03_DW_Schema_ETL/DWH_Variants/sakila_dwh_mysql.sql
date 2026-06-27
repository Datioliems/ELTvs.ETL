-- ============================================================
-- KHO DỮ LIỆU SAKILA – MySQL Version
-- Dành cho cấu trúc đã tách schema:
--   sakila_crm      : customer, address, city, country
--   sakila_hrm      : staff, store, address, city, country
--   sakila_inventory: film, category, film_category, inventory, language
--   sakila_sales    : rental, payment
--
-- Cách chạy trong phpMyAdmin:
--   1. Vào tab SQL hoặc Import
--   2. Paste hoặc upload file này
--   3. Nhấn Go/Execute
-- ============================================================

DROP SCHEMA IF EXISTS sakila_dwh;
CREATE SCHEMA sakila_dwh DEFAULT CHARACTER SET utf8mb4;
USE sakila_dwh;

-- ============================================================
-- DIM_DATE
-- Sinh tự động, không lấy từ OLTP
-- ============================================================
CREATE TABLE Dim_Date (
    date_key        INT          NOT NULL,
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
    is_weekend      TINYINT,
    is_holiday      TINYINT DEFAULT 0,
    PRIMARY KEY (date_key)
);

-- Dòng đặc biệt cho return_date = NULL (chưa trả)
INSERT INTO Dim_Date VALUES
(-1, NULL, NULL, 'Chưa trả', NULL, NULL, NULL, NULL, 'Chưa trả', NULL, NULL, NULL, 0);

-- Sinh ngày tự động 2005-01-01 đến 2006-12-31
DROP PROCEDURE IF EXISTS sakila_dwh.fill_dim_date;
DELIMITER $$
CREATE PROCEDURE sakila_dwh.fill_dim_date()
BEGIN
    DECLARE cur     DATE DEFAULT '2005-01-01';
    DECLARE end_dt  DATE DEFAULT '2006-12-31';
    WHILE cur <= end_dt DO
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

CALL sakila_dwh.fill_dim_date();
DROP PROCEDURE IF EXISTS sakila_dwh.fill_dim_date;

-- ============================================================
-- DIM_PRODUCT
-- Nguồn: sakila_inventory.film + film_category + category + language
-- ============================================================
CREATE TABLE Dim_Product (
    product_key      INT          NOT NULL AUTO_INCREMENT,
    film_id          INT          NOT NULL,
    title            VARCHAR(255) NOT NULL,
    description      TEXT,
    release_year     YEAR,
    language_name    VARCHAR(50),
    rental_duration  INT,
    rental_rate      DECIMAL(4,2),
    length_minutes   INT,
    replacement_cost DECIMAL(5,2),
    rating           VARCHAR(10),
    special_features VARCHAR(255),
    category_id      INT,
    category_name    VARCHAR(25),
    inventory_count  INT,
    is_active        TINYINT  DEFAULT 1,
    effective_date   DATE,
    source_system    VARCHAR(30) DEFAULT 'SAKILA_INVENTORY',
    PRIMARY KEY (product_key),
    INDEX idx_film_id (film_id)
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
FROM sakila_inventory.film          f
JOIN sakila_inventory.language      l  ON f.language_id      = l.language_id
LEFT JOIN sakila_inventory.film_category fc ON f.film_id     = fc.film_id
LEFT JOIN sakila_inventory.category c  ON fc.category_id     = c.category_id
LEFT JOIN sakila_inventory.inventory i  ON f.film_id         = i.film_id
GROUP BY
    f.film_id, f.title, f.description, f.release_year,
    l.name, f.rental_duration, f.rental_rate,
    f.length, f.replacement_cost, f.rating, f.special_features,
    c.category_id, c.name;

-- ============================================================
-- DIM_CUSTOMER
-- Nguồn: sakila_crm.customer + address + city + country
-- ============================================================
CREATE TABLE Dim_Customer (
    customer_key   INT          NOT NULL AUTO_INCREMENT,
    customer_id    INT          NOT NULL,
    first_name     VARCHAR(45),
    last_name      VARCHAR(45),
    full_name      VARCHAR(91),
    email          VARCHAR(50),
    address        VARCHAR(50),
    address2       VARCHAR(50),
    district       VARCHAR(20),
    postal_code    VARCHAR(10),
    phone          VARCHAR(20),
    city_id        INT,
    city_name      VARCHAR(50),
    country_id     INT,
    country_name   VARCHAR(50),
    store_id       INT,
    active         TINYINT,
    customer_class VARCHAR(10) DEFAULT 'Bronze',
    create_date    DATETIME,
    is_current     TINYINT     DEFAULT 1,
    effective_date DATE,
    source_system  VARCHAR(30) DEFAULT 'SAKILA_CRM',
    PRIMARY KEY (customer_key),
    INDEX idx_customer_id (customer_id)
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
FROM sakila_crm.customer    c
JOIN sakila_crm.address     a  ON c.address_id  = a.address_id
JOIN sakila_crm.city        ci ON a.city_id     = ci.city_id
JOIN sakila_crm.country     co ON ci.country_id = co.country_id;

-- Phân hạng Gold / Silver / Bronze theo tổng chi tiêu
UPDATE Dim_Customer dc
JOIN (
    SELECT
        c.customer_id,
        NTILE(10) OVER (ORDER BY SUM(p.amount) DESC) AS decile
    FROM sakila_crm.customer    c
    JOIN sakila_sales.payment   p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
) ranked ON dc.customer_id = ranked.customer_id
SET dc.customer_class = CASE
    WHEN ranked.decile = 1  THEN 'Gold'
    WHEN ranked.decile <= 4 THEN 'Silver'
    ELSE 'Bronze'
END;

-- ============================================================
-- DIM_GEOGRAPHY_STORE
-- Nguồn: sakila_hrm.store + staff(manager) + address + city + country
-- ============================================================
CREATE TABLE Dim_Geography_Store (
    store_key     INT          NOT NULL AUTO_INCREMENT,
    store_id      INT          NOT NULL,
    store_name    VARCHAR(50),
    manager_name  VARCHAR(91),
    address       VARCHAR(50),
    address2      VARCHAR(50),
    district      VARCHAR(20),
    postal_code   VARCHAR(10),
    phone         VARCHAR(20),
    city_id       INT,
    city_name     VARCHAR(50),
    country_id    INT,
    country_name  VARCHAR(50),
    is_active     TINYINT  DEFAULT 1,
    effective_date DATE,
    source_system VARCHAR(30) DEFAULT 'SAKILA_HRM',
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
FROM sakila_hrm.store    s
JOIN sakila_hrm.staff    m  ON s.manager_staff_id = m.staff_id
JOIN sakila_hrm.address  a  ON s.address_id       = a.address_id
JOIN sakila_hrm.city     ci ON a.city_id          = ci.city_id
JOIN sakila_hrm.country  co ON ci.country_id      = co.country_id;

-- ============================================================
-- DIM_STAFF
-- Nguồn: sakila_hrm.staff + store + address + city + country
-- ============================================================
CREATE TABLE Dim_Staff (
    staff_key      INT          NOT NULL AUTO_INCREMENT,
    staff_id       INT          NOT NULL,
    first_name     VARCHAR(45),
    last_name      VARCHAR(45),
    full_name      VARCHAR(91),
    email          VARCHAR(50),
    username       VARCHAR(16),
    active         TINYINT,
    store_id       INT,
    store_name     VARCHAR(50),
    address        VARCHAR(50),
    address2       VARCHAR(50),
    district       VARCHAR(20),
    city_name      VARCHAR(50),
    country_name   VARCHAR(50),
    is_current     TINYINT  DEFAULT 1,
    effective_date DATE,
    source_system  VARCHAR(30) DEFAULT 'SAKILA_HRM',
    PRIMARY KEY (staff_key),
    INDEX idx_staff_id (staff_id)
);

INSERT INTO Dim_Staff (
    staff_id, first_name, last_name, full_name,
    email, username, active,
    store_id, store_name,
    address, address2, district,
    city_name, country_name,
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
FROM sakila_hrm.staff    s
JOIN sakila_hrm.address  a  ON s.address_id  = a.address_id
JOIN sakila_hrm.city     ci ON a.city_id     = ci.city_id
JOIN sakila_hrm.country  co ON ci.country_id = co.country_id;

-- ============================================================
-- FACT_SALE (Transaction Fact)
-- Nguồn: sakila_sales.rental + payment
--        sakila_inventory.inventory + film
-- ============================================================
CREATE TABLE Fact_Sale (
    sale_key                 INT          NOT NULL AUTO_INCREMENT,
    rental_id                INT,
    rental_date_key          INT,
    return_date_key          INT,
    payment_date_key         INT,
    customer_key             INT,
    product_key              INT,
    store_key                INT,
    staff_key                INT,
    amount                   DECIMAL(5,2),
    rental_duration_expected INT,
    rental_duration_actual   INT,
    late_days                INT,
    is_late                  TINYINT,
    is_returned              TINYINT,
    replacement_cost         DECIMAL(5,2),
    last_update              DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sale_key),
    INDEX idx_rental_date (rental_date_key),
    INDEX idx_return_date (return_date_key),
    INDEX idx_customer    (customer_key),
    INDEX idx_product     (product_key),
    INDEX idx_store       (store_key),
    INDEX idx_staff       (staff_key),
    INDEX idx_rental_id   (rental_id)
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
    COALESCE(d_r.date_key,   -1),
    COALESCE(d_ret.date_key, -1),
    COALESCE(d_p.date_key,   -1),
    dc.customer_key,
    dp.product_key,
    dg.store_key,
    ds.staff_key,
    p.amount,
    f.rental_duration,
    DATEDIFF(r.return_date, r.rental_date),
    GREATEST(0, COALESCE(
        DATEDIFF(r.return_date,
                 DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)), 0)),
    CASE WHEN r.return_date IS NOT NULL
          AND DATEDIFF(r.return_date,
                       DATE_ADD(r.rental_date, INTERVAL f.rental_duration DAY)) > 0
         THEN 1 ELSE 0 END,
    IF(r.return_date IS NOT NULL, 1, 0),
    f.replacement_cost
FROM sakila_sales.rental            r
JOIN sakila_sales.payment           p    ON r.rental_id    = p.rental_id
JOIN sakila_inventory.inventory     i    ON r.inventory_id = i.inventory_id
JOIN sakila_inventory.film          f    ON i.film_id      = f.film_id
JOIN sakila_dwh.Dim_Date            d_r  ON DATE(r.rental_date)  = d_r.date
LEFT JOIN sakila_dwh.Dim_Date       d_ret ON DATE(r.return_date) = d_ret.date
JOIN sakila_dwh.Dim_Date            d_p  ON DATE(p.payment_date) = d_p.date
JOIN sakila_dwh.Dim_Customer        dc   ON r.customer_id = dc.customer_id  AND dc.is_current = 1
JOIN sakila_dwh.Dim_Product         dp   ON i.film_id     = dp.film_id      AND dp.is_active  = 1
JOIN sakila_dwh.Dim_Geography_Store dg   ON i.store_id    = dg.store_id
JOIN sakila_dwh.Dim_Staff           ds   ON r.staff_id    = ds.staff_id     AND ds.is_current = 1;

-- Role-Playing Views
CREATE OR REPLACE VIEW Dim_RentalDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_ReturnDate  AS SELECT * FROM Dim_Date;
CREATE OR REPLACE VIEW Dim_PaymentDate AS SELECT * FROM Dim_Date;

-- ============================================================
-- FACT_FILM_COVERAGE (Factless Fact)
-- Nguồn: sakila_inventory.inventory
-- ============================================================
CREATE TABLE Fact_Film_Coverage (
    date_key    INT NOT NULL,
    product_key INT NOT NULL,
    store_key   INT NOT NULL,
    PRIMARY KEY (date_key, product_key, store_key),
    INDEX idx_product (product_key),
    INDEX idx_store   (store_key)
);

-- Nạp cho range có dữ liệu (tháng 5/2005 đến 8/2006)
INSERT INTO Fact_Film_Coverage (date_key, product_key, store_key)
SELECT DISTINCT
    d.date_key,
    dp.product_key,
    dg.store_key
FROM sakila_inventory.inventory     i
JOIN sakila_dwh.Dim_Product         dp ON i.film_id  = dp.film_id
JOIN sakila_dwh.Dim_Geography_Store dg ON i.store_id = dg.store_id
CROSS JOIN sakila_dwh.Dim_Date      d
WHERE d.date BETWEEN '2005-05-01' AND '2006-08-31'
  AND d.date_key > 0;

-- ============================================================
-- AGGREGATE FACTS
-- ============================================================

-- byCustomer
CREATE TABLE Fact_Sale_byCustomer (
    date_key         INT           NOT NULL,
    customer_key     INT           NOT NULL,
    store_key        INT           NOT NULL,
    customer_class   VARCHAR(10),
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    late_count       INT,
    unreturned_count INT,
    total_late_days  INT,
    arpu             DECIMAL(10,2),
    PRIMARY KEY (date_key, customer_key, store_key)
);

INSERT INTO Fact_Sale_byCustomer
SELECT
    fs.rental_date_key,
    fs.customer_key,
    fs.store_key,
    dc.customer_class,
    COUNT(*),
    SUM(fs.amount),
    SUM(fs.is_late),
    SUM(CASE WHEN fs.is_returned = 0 THEN 1 ELSE 0 END),
    SUM(fs.late_days),
    SUM(fs.amount) / COUNT(DISTINCT fs.customer_key)
FROM sakila_dwh.Fact_Sale     fs
JOIN sakila_dwh.Dim_Customer  dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, fs.customer_key, fs.store_key, dc.customer_class;

-- byProduct
CREATE TABLE Fact_Sale_byProduct (
    date_key            INT           NOT NULL,
    product_key         INT           NOT NULL,
    store_key           INT           NOT NULL,
    total_rentals       INT,
    total_amount        DECIMAL(10,2),
    avg_duration_actual DECIMAL(5,2),
    late_count          INT,
    PRIMARY KEY (date_key, product_key, store_key)
);

INSERT INTO Fact_Sale_byProduct
SELECT
    rental_date_key, product_key, store_key,
    COUNT(*), SUM(amount),
    AVG(rental_duration_actual),
    SUM(is_late)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, product_key, store_key;

-- byStore
CREATE TABLE Fact_Sale_byStore (
    date_key               INT           NOT NULL,
    store_key              INT           NOT NULL,
    total_rentals          INT,
    total_amount           DECIMAL(10,2),
    total_late_count       INT,
    unreturned_count       INT,
    total_replacement_risk DECIMAL(10,2),
    PRIMARY KEY (date_key, store_key)
);

INSERT INTO Fact_Sale_byStore
SELECT
    rental_date_key, store_key,
    COUNT(*),
    SUM(amount),
    SUM(is_late),
    SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_returned = 0 THEN replacement_cost ELSE 0 END)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, store_key;

-- byStaff
CREATE TABLE Fact_Sale_byStaff (
    date_key        INT           NOT NULL,
    staff_key       INT           NOT NULL,
    store_key       INT           NOT NULL,
    total_rentals   INT,
    total_amount    DECIMAL(10,2),
    total_customers INT,
    arpo            DECIMAL(10,2),
    PRIMARY KEY (date_key, staff_key, store_key)
);

INSERT INTO Fact_Sale_byStaff
SELECT
    rental_date_key, staff_key, store_key,
    COUNT(*), SUM(amount),
    COUNT(DISTINCT customer_key),
    SUM(amount) / COUNT(*)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, staff_key, store_key;

-- byDate
CREATE TABLE Fact_Sale_byDate (
    date_key          INT           NOT NULL,
    store_key         INT           NOT NULL,
    total_rentals     INT,
    total_amount      DECIMAL(10,2),
    total_late_count  INT,
    late_rate         DECIMAL(5,2),
    PRIMARY KEY (date_key, store_key)
);

INSERT INTO Fact_Sale_byDate
SELECT
    rental_date_key, store_key,
    COUNT(*),
    SUM(amount),
    SUM(is_late),
    ROUND(SUM(is_late) / COUNT(*) * 100, 2)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, store_key;

-- byCategory
CREATE TABLE Fact_Sale_byCategory (
    date_key              INT           NOT NULL,
    product_key           INT           NOT NULL,
    store_key             INT           NOT NULL,
    total_rentals         INT,
    total_amount          DECIMAL(10,2),
    unique_customers      INT,
    avg_amount_per_rental DECIMAL(5,2),
    PRIMARY KEY (date_key, product_key, store_key)
);

INSERT INTO Fact_Sale_byCategory
SELECT
    rental_date_key, product_key, store_key,
    COUNT(*), SUM(amount),
    COUNT(DISTINCT customer_key),
    SUM(amount) / COUNT(*)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, product_key, store_key;

-- byRegion
CREATE TABLE Fact_Sale_byRegion (
    date_key        INT           NOT NULL,
    customer_key    INT           NOT NULL,
    total_customers INT,
    total_rentals   INT,
    total_amount    DECIMAL(10,2),
    arpu            DECIMAL(10,2),
    PRIMARY KEY (date_key, customer_key)
);

INSERT INTO Fact_Sale_byRegion
SELECT
    rental_date_key, customer_key,
    COUNT(DISTINCT customer_key),
    COUNT(*), SUM(amount),
    SUM(amount) / COUNT(DISTINCT customer_key)
FROM sakila_dwh.Fact_Sale
GROUP BY rental_date_key, customer_key;

-- ============================================================
-- KIỂM TRA SỐ DÒNG
-- ============================================================
SELECT 'Dim_Date'           AS bang, COUNT(*) AS so_dong FROM Dim_Date
UNION ALL SELECT 'Dim_Product',          COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Customer',         COUNT(*) FROM Dim_Customer
UNION ALL SELECT 'Dim_Geography_Store',  COUNT(*) FROM Dim_Geography_Store
UNION ALL SELECT 'Dim_Staff',            COUNT(*) FROM Dim_Staff
UNION ALL SELECT 'Fact_Sale',            COUNT(*) FROM Fact_Sale
UNION ALL SELECT 'Fact_Film_Coverage',   COUNT(*) FROM Fact_Film_Coverage
UNION ALL SELECT 'Fact_Sale_byCustomer', COUNT(*) FROM Fact_Sale_byCustomer
UNION ALL SELECT 'Fact_Sale_byProduct',  COUNT(*) FROM Fact_Sale_byProduct
UNION ALL SELECT 'Fact_Sale_byStore',    COUNT(*) FROM Fact_Sale_byStore
UNION ALL SELECT 'Fact_Sale_byStaff',    COUNT(*) FROM Fact_Sale_byStaff
UNION ALL SELECT 'Fact_Sale_byDate',     COUNT(*) FROM Fact_Sale_byDate
UNION ALL SELECT 'Fact_Sale_byCategory', COUNT(*) FROM Fact_Sale_byCategory
UNION ALL SELECT 'Fact_Sale_byRegion',   COUNT(*) FROM Fact_Sale_byRegion;
