USE dwh;

-- ============================================================
-- BƯỚC 1: TẠO CẤU TRÚC CÁC BẢNG AGGREGATE
-- ============================================================

CREATE TABLE IF NOT EXISTS Fact_Film_Coverage (
    date_key     INT  NOT NULL,
    product_key  INT  NOT NULL,
    store_key    INT  NOT NULL,
    PRIMARY KEY (date_key, product_key, store_key),
    INDEX idx_product (product_key),
    INDEX idx_store   (store_key)
);

CREATE TABLE IF NOT EXISTS Fact_Sale_byCustomer (
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

CREATE TABLE IF NOT EXISTS Fact_Sale_byProduct (
    date_key             INT            NOT NULL,
    product_key          INT            NOT NULL,
    store_key            INT            NOT NULL,
    total_rentals        INT,
    total_amount         DECIMAL(10,2),
    avg_duration_actual  DECIMAL(5,2),
    late_count           INT,
    PRIMARY KEY (date_key, product_key, store_key)
);

CREATE TABLE IF NOT EXISTS Fact_Sale_byStore (
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

CREATE TABLE IF NOT EXISTS Fact_Sale_byStaff (
    date_key         INT            NOT NULL,
    staff_key        INT            NOT NULL,
    store_key        INT            NOT NULL,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    total_customers  INT,
    arpo             DECIMAL(10,2),
    PRIMARY KEY (date_key, staff_key, store_key)
);

CREATE TABLE IF NOT EXISTS Fact_Sale_byDate (
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

CREATE TABLE IF NOT EXISTS Fact_Sale_byCategory (
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

CREATE TABLE IF NOT EXISTS Fact_Sale_byRegion (
    date_key         INT            NOT NULL,
    city_name        VARCHAR(50)    NOT NULL,
    country_name     VARCHAR(50)    NOT NULL,
    total_customers  INT,
    total_rentals    INT,
    total_amount     DECIMAL(10,2),
    arpu             DECIMAL(10,2),
    PRIMARY KEY (date_key, city_name, country_name)
);

-- ============================================================
-- BƯỚC 2: NẠP DỮ LIỆU VÀO CÁC BẢNG AGGREGATE
-- ============================================================

INSERT INTO Fact_Film_Coverage (date_key, product_key, store_key)
SELECT DISTINCT
    d.date_key,
    dp.product_key,
    dg.store_key
FROM sakila.inventory        i
JOIN dwh.Dim_Product         dp ON i.film_id  = dp.film_id
JOIN dwh.Dim_Geography_Store dg ON i.store_id = dg.store_id
JOIN dwh.Dim_Date            d  ON d.date_key > 0
                                AND d.day_of_month = 1
                                AND d.date BETWEEN '2005-05-01' AND '2006-08-31';

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
FROM dwh.Fact_Sale fs
JOIN dwh.Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, fs.customer_key, fs.store_key, dc.customer_class;

INSERT INTO Fact_Sale_byProduct
SELECT
    rental_date_key,
    product_key,
    store_key,
    COUNT(*)                    AS total_rentals,
    SUM(amount)                 AS total_amount,
    AVG(rental_duration_actual) AS avg_duration_actual,
    SUM(is_late)                AS late_count
FROM dwh.Fact_Sale
GROUP BY rental_date_key, product_key, store_key;

INSERT INTO Fact_Sale_byStore
SELECT
    rental_date_key,
    store_key,
    COUNT(*)                                                        AS total_rentals,
    SUM(amount)                                                     AS total_amount,
    SUM(is_late)                                                    AS total_late_count,
    SUM(CASE WHEN is_returned = 0 THEN 1 ELSE 0 END)                AS unreturned_count,
    SUM(CASE WHEN is_returned = 0 THEN replacement_cost ELSE 0 END) AS total_replacement_cost,
    ROUND(SUM(amount) / NULLIF(COUNT(DISTINCT customer_key), 0), 2) AS arpu
FROM dwh.Fact_Sale
GROUP BY rental_date_key, store_key;

INSERT INTO Fact_Sale_byStaff
SELECT
    rental_date_key,
    staff_key,
    store_key,
    COUNT(*)                                    AS total_rentals,
    SUM(amount)                                 AS total_amount,
    COUNT(DISTINCT customer_key)                AS total_customers,
    ROUND(SUM(amount) / NULLIF(COUNT(*), 0), 2) AS arpo
FROM dwh.Fact_Sale
GROUP BY rental_date_key, staff_key, store_key;

INSERT INTO Fact_Sale_byDate
WITH grouped AS (
    SELECT
        fs.rental_date_key,
        fs.store_key,
        d.year,
        d.month_of_year,
        COUNT(*)                                    AS total_rentals,
        SUM(fs.amount)                              AS total_amount,
        SUM(fs.is_late)                             AS total_late_count,
        ROUND(SUM(fs.is_late) / COUNT(*) * 100, 2)  AS late_rate
    FROM dwh.Fact_Sale fs
    JOIN dwh.Dim_Date d ON fs.rental_date_key = d.date_key
    GROUP BY fs.rental_date_key, fs.store_key, d.year, d.month_of_year
)
SELECT
    rental_date_key, store_key, year, month_of_year,
    total_rentals, total_amount, total_late_count, late_rate,
    SUM(total_amount) OVER (
        PARTITION BY store_key, year
        ORDER BY rental_date_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_amount
FROM grouped;

INSERT INTO Fact_Sale_byCategory
SELECT
    fs.rental_date_key,
    dp.category_name,
    fs.store_key,
    COUNT(*)                                                          AS total_rentals,
    COUNT(DISTINCT fs.customer_key)                                   AS unique_customers,
    SUM(fs.amount)                                                    AS total_amount,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(*), 0), 2)                    AS avg_amount_per_rental,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(DISTINCT fs.customer_key), 0), 2) AS arpu
FROM dwh.Fact_Sale fs
JOIN dwh.Dim_Product dp ON fs.product_key = dp.product_key
GROUP BY fs.rental_date_key, dp.category_name, fs.store_key;

INSERT INTO Fact_Sale_byRegion
SELECT
    fs.rental_date_key,
    dc.city_name,
    dc.country_name,
    COUNT(DISTINCT fs.customer_key)                                       AS total_customers,
    COUNT(*)                                                              AS total_rentals,
    SUM(fs.amount)                                                        AS total_amount,
    ROUND(SUM(fs.amount) / NULLIF(COUNT(DISTINCT fs.customer_key), 0), 2) AS arpu
FROM dwh.Fact_Sale fs
JOIN dwh.Dim_Customer dc ON fs.customer_key = dc.customer_key
GROUP BY fs.rental_date_key, dc.city_name, dc.country_name;

-- ============================================================
-- BƯỚC 3: KIỂM TRA KẾT QUẢ
-- ============================================================
SELECT 'Fact_Film_Coverage'   AS bang, COUNT(*) AS so_dong FROM dwh.Fact_Film_Coverage
UNION ALL SELECT 'byCustomer', COUNT(*) FROM dwh.Fact_Sale_byCustomer
UNION ALL SELECT 'byProduct',  COUNT(*) FROM dwh.Fact_Sale_byProduct
UNION ALL SELECT 'byStore',    COUNT(*) FROM dwh.Fact_Sale_byStore
UNION ALL SELECT 'byStaff',    COUNT(*) FROM dwh.Fact_Sale_byStaff
UNION ALL SELECT 'byDate',     COUNT(*) FROM dwh.Fact_Sale_byDate
UNION ALL SELECT 'byCategory', COUNT(*) FROM dwh.Fact_Sale_byCategory
UNION ALL SELECT 'byRegion',   COUNT(*) FROM dwh.Fact_Sale_byRegion;
