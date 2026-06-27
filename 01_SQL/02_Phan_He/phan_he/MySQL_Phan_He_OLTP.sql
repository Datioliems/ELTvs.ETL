-- ============================================================
-- FILE: MySQL_Phan_He_OLTP.sql
-- MỤC ĐÍCH: Tạo 4 database phân hệ trên MySQL từ Sakila gốc
-- CHẠY TRÊN: MySQL Workbench (kết nối vào MySQL server)
-- YÊU CẦU: Database sakila gốc phải tồn tại
-- ============================================================

-- ============================================================
-- PHÂN HỆ 1: sakila_sales (Phân hệ Bán hàng)
-- Bảng: rental, payment
-- Mô tả: Quản lý toàn bộ giao dịch thuê và thanh toán
-- ============================================================
DROP DATABASE IF EXISTS sakila_sales;
CREATE DATABASE sakila_sales CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sakila_sales;

CREATE TABLE rental (
    rental_id       INT             NOT NULL AUTO_INCREMENT,
    rental_date     DATETIME        NOT NULL,
    inventory_id    MEDIUMINT       NOT NULL,
    customer_id     SMALLINT        NOT NULL,
    return_date     DATETIME        NULL,
    staff_id        TINYINT         NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (rental_id),
    INDEX idx_rental_date        (rental_date),
    INDEX idx_inventory_id       (inventory_id),
    INDEX idx_customer_id        (customer_id),
    INDEX idx_staff_id           (staff_id)
);

CREATE TABLE payment (
    payment_id      SMALLINT        NOT NULL AUTO_INCREMENT,
    customer_id     SMALLINT        NOT NULL,
    staff_id        TINYINT         NOT NULL,
    rental_id       INT             NULL,
    amount          DECIMAL(5,2)    NOT NULL,
    payment_date    DATETIME        NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    INDEX idx_customer_id    (customer_id),
    INDEX idx_staff_id       (staff_id),
    INDEX idx_rental_id      (rental_id)
);

-- Sao chép dữ liệu từ Sakila gốc
INSERT INTO rental SELECT * FROM sakila.rental;
INSERT INTO payment SELECT * FROM sakila.payment;

SELECT 'sakila_sales' AS database_name,
       'rental'       AS table_name,
       COUNT(*)       AS row_count FROM rental
UNION ALL
SELECT 'sakila_sales', 'payment', COUNT(*) FROM payment;


-- ============================================================
-- PHÂN HỆ 2: sakila_crm (Phân hệ Quản lý Khách hàng)
-- Bảng: customer, address, city, country
-- Mô tả: Quản lý hồ sơ và địa chỉ khách hàng
-- ============================================================
DROP DATABASE IF EXISTS sakila_crm;
CREATE DATABASE sakila_crm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sakila_crm;

CREATE TABLE country (
    country_id      SMALLINT        NOT NULL AUTO_INCREMENT,
    country         VARCHAR(50)     NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (country_id)
);

CREATE TABLE city (
    city_id         SMALLINT        NOT NULL AUTO_INCREMENT,
    city            VARCHAR(50)     NOT NULL,
    country_id      SMALLINT        NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (city_id),
    INDEX idx_country_id (country_id)
);

CREATE TABLE address (
    address_id      SMALLINT        NOT NULL AUTO_INCREMENT,
    address         VARCHAR(50)     NOT NULL,
    address2        VARCHAR(50)     NULL,
    district        VARCHAR(20)     NOT NULL,
    city_id         SMALLINT        NOT NULL,
    postal_code     VARCHAR(10)     NULL,
    phone           VARCHAR(20)     NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id),
    INDEX idx_city_id (city_id)
);

CREATE TABLE customer (
    customer_id     SMALLINT        NOT NULL AUTO_INCREMENT,
    store_id        TINYINT         NOT NULL,
    first_name      VARCHAR(45)     NOT NULL,
    last_name       VARCHAR(45)     NOT NULL,
    email           VARCHAR(50)     NULL,
    address_id      SMALLINT        NOT NULL,
    active          TINYINT(1)      NOT NULL DEFAULT 1,
    create_date     DATETIME        NOT NULL,
    last_update     TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    INDEX idx_address_id (address_id),
    INDEX idx_store_id   (store_id)
);

-- Sao chép dữ liệu
INSERT INTO country  SELECT * FROM sakila.country;
INSERT INTO city     SELECT * FROM sakila.city;
INSERT INTO address  SELECT * FROM sakila.address;
INSERT INTO customer SELECT * FROM sakila.customer;

SELECT 'sakila_crm' AS database_name,
       'country'    AS table_name,
       COUNT(*)     AS row_count FROM country
UNION ALL SELECT 'sakila_crm', 'city',     COUNT(*) FROM city
UNION ALL SELECT 'sakila_crm', 'address',  COUNT(*) FROM address
UNION ALL SELECT 'sakila_crm', 'customer', COUNT(*) FROM customer;


-- ============================================================
-- PHÂN HỆ 3: sakila_inventory (Phân hệ Quản lý Kho)
-- Bảng: film, film_category, category, language, inventory
-- Mô tả: Quản lý danh mục phim và tồn kho đĩa
-- ============================================================
DROP DATABASE IF EXISTS sakila_inventory;
CREATE DATABASE sakila_inventory CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sakila_inventory;

CREATE TABLE language (
    language_id     TINYINT         NOT NULL AUTO_INCREMENT,
    name            CHAR(20)        NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (language_id)
);

CREATE TABLE film (
    film_id             SMALLINT        NOT NULL AUTO_INCREMENT,
    title               VARCHAR(255)    NOT NULL,
    description         TEXT            NULL,
    release_year        YEAR            NULL,
    language_id         TINYINT         NOT NULL,
    original_language_id TINYINT        NULL,
    rental_duration     TINYINT         NOT NULL DEFAULT 3,
    rental_rate         DECIMAL(4,2)    NOT NULL DEFAULT 4.99,
    length              SMALLINT        NULL,
    replacement_cost    DECIMAL(5,2)    NOT NULL DEFAULT 19.99,
    rating              ENUM('G','PG','PG-13','R','NC-17') DEFAULT 'G',
    special_features    SET('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') NULL,
    last_update         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (film_id),
    INDEX idx_language_id (language_id)
);

CREATE TABLE category (
    category_id     TINYINT         NOT NULL AUTO_INCREMENT,
    name            VARCHAR(25)     NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (category_id)
);

CREATE TABLE film_category (
    film_id         SMALLINT        NOT NULL,
    category_id     TINYINT         NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (film_id, category_id)
);

CREATE TABLE inventory (
    inventory_id    MEDIUMINT       NOT NULL AUTO_INCREMENT,
    film_id         SMALLINT        NOT NULL,
    store_id        TINYINT         NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (inventory_id),
    INDEX idx_film_id  (film_id),
    INDEX idx_store_id (store_id)
);

-- Sao chép dữ liệu
INSERT INTO language      SELECT * FROM sakila.language;
INSERT INTO film          SELECT * FROM sakila.film;
INSERT INTO category      SELECT * FROM sakila.category;
INSERT INTO film_category SELECT * FROM sakila.film_category;
INSERT INTO inventory     SELECT * FROM sakila.inventory;

SELECT 'sakila_inventory' AS database_name,
       'language'         AS table_name,
       COUNT(*)           AS row_count FROM language
UNION ALL SELECT 'sakila_inventory', 'film',          COUNT(*) FROM film
UNION ALL SELECT 'sakila_inventory', 'category',      COUNT(*) FROM category
UNION ALL SELECT 'sakila_inventory', 'film_category', COUNT(*) FROM film_category
UNION ALL SELECT 'sakila_inventory', 'inventory',     COUNT(*) FROM inventory;


-- ============================================================
-- PHÂN HỆ 4: sakila_hrm (Phân hệ Quản lý Nhân sự)
-- Bảng: staff, store, address, city, country (cho nhân viên)
-- Mô tả: Quản lý nhân viên và cửa hàng
-- ============================================================
DROP DATABASE IF EXISTS sakila_hrm;
CREATE DATABASE sakila_hrm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sakila_hrm;

CREATE TABLE country (
    country_id      SMALLINT        NOT NULL AUTO_INCREMENT,
    country         VARCHAR(50)     NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (country_id)
);

CREATE TABLE city (
    city_id         SMALLINT        NOT NULL AUTO_INCREMENT,
    city            VARCHAR(50)     NOT NULL,
    country_id      SMALLINT        NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (city_id)
);

CREATE TABLE address (
    address_id      SMALLINT        NOT NULL AUTO_INCREMENT,
    address         VARCHAR(50)     NOT NULL,
    address2        VARCHAR(50)     NULL,
    district        VARCHAR(20)     NOT NULL,
    city_id         SMALLINT        NOT NULL,
    postal_code     VARCHAR(10)     NULL,
    phone           VARCHAR(20)     NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id)
);

CREATE TABLE store (
    store_id        TINYINT         NOT NULL AUTO_INCREMENT,
    manager_staff_id TINYINT        NOT NULL,
    address_id      SMALLINT        NOT NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (store_id)
);

CREATE TABLE staff (
    staff_id        TINYINT         NOT NULL AUTO_INCREMENT,
    first_name      VARCHAR(45)     NOT NULL,
    last_name       VARCHAR(45)     NOT NULL,
    address_id      SMALLINT        NOT NULL,
    email           VARCHAR(50)     NULL,
    store_id        TINYINT         NOT NULL,
    active          TINYINT(1)      NOT NULL DEFAULT 1,
    username        VARCHAR(16)     NOT NULL,
    password        VARCHAR(40)     NULL,
    last_update     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (staff_id)
);

-- Sao chép dữ liệu (chỉ lấy country/city/address liên quan đến staff)
INSERT INTO country SELECT DISTINCT co.*
FROM sakila.country co
INNER JOIN sakila.city ci     ON co.country_id = ci.country_id
INNER JOIN sakila.address a   ON ci.city_id    = a.city_id
INNER JOIN sakila.staff st    ON a.address_id  = st.address_id;

INSERT INTO city SELECT DISTINCT ci.*
FROM sakila.city ci
INNER JOIN sakila.address a ON ci.city_id   = a.city_id
INNER JOIN sakila.staff st  ON a.address_id = st.address_id;

INSERT INTO address SELECT DISTINCT a.*
FROM sakila.address a
INNER JOIN sakila.staff st ON a.address_id = st.address_id;

-- Thêm address của store nếu chưa có
INSERT IGNORE INTO address SELECT a.*
FROM sakila.address a
INNER JOIN sakila.store s ON a.address_id = s.address_id;

INSERT INTO store  SELECT * FROM sakila.store;
INSERT INTO staff  SELECT staff_id, first_name, last_name, address_id,
                          email, store_id, active, username, password, last_update
                   FROM sakila.staff;

SELECT 'sakila_hrm' AS database_name,
       'country'    AS table_name,
       COUNT(*)     AS row_count FROM country
UNION ALL SELECT 'sakila_hrm', 'city',    COUNT(*) FROM city
UNION ALL SELECT 'sakila_hrm', 'address', COUNT(*) FROM address
UNION ALL SELECT 'sakila_hrm', 'store',   COUNT(*) FROM store
UNION ALL SELECT 'sakila_hrm', 'staff',   COUNT(*) FROM staff;

-- ============================================================
-- KIỂM TRA TỔNG QUAN 4 PHÂN HỆ
-- ============================================================
SELECT
    'sakila_sales'     AS phan_he, 'rental'  AS bang, COUNT(*) AS so_dong FROM sakila_sales.rental
UNION ALL SELECT 'sakila_sales',     'payment',       COUNT(*) FROM sakila_sales.payment
UNION ALL SELECT 'sakila_crm',       'customer',      COUNT(*) FROM sakila_crm.customer
UNION ALL SELECT 'sakila_crm',       'address',       COUNT(*) FROM sakila_crm.address
UNION ALL SELECT 'sakila_inventory', 'film',          COUNT(*) FROM sakila_inventory.film
UNION ALL SELECT 'sakila_inventory', 'inventory',     COUNT(*) FROM sakila_inventory.inventory
UNION ALL SELECT 'sakila_hrm',       'staff',         COUNT(*) FROM sakila_hrm.staff
UNION ALL SELECT 'sakila_hrm',       'store',         COUNT(*) FROM sakila_hrm.store;
