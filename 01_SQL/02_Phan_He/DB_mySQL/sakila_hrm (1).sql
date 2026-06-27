-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Máy chủ: 127.0.0.1
-- Thời gian đã tạo: Th5 19, 2026 lúc 04:05 AM
-- Phiên bản máy phục vụ: 10.4.32-MariaDB
-- Phiên bản PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Cơ sở dữ liệu: `sakila_hrm`
--
CREATE DATABASE IF NOT EXISTS `sakila_hrm` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `sakila_hrm`;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `address`
--

DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
  `address_id` smallint(6) NOT NULL,
  `address` varchar(50) NOT NULL,
  `address2` varchar(50) DEFAULT NULL,
  `district` varchar(20) NOT NULL,
  `city_id` smallint(6) NOT NULL,
  `postal_code` varchar(10) DEFAULT NULL,
  `phone` varchar(20) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `address`
--

INSERT INTO `address` (`address_id`, `address`, `address2`, `district`, `city_id`, `postal_code`, `phone`, `last_update`) VALUES
(1, '47 MySakila Drive', NULL, ' ', 300, NULL, ' ', '2006-02-14 21:45:30'),
(2, '28 MySQL Boulevard', NULL, ' ', 576, NULL, ' ', '2006-02-14 21:45:30'),
(3, '23 Workhaven Lane', NULL, ' ', 300, NULL, ' ', '2006-02-14 21:45:30'),
(4, '1411 Lillydale Drive', NULL, ' ', 576, NULL, ' ', '2006-02-14 21:45:30');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `city`
--

DROP TABLE IF EXISTS `city`;
CREATE TABLE `city` (
  `city_id` smallint(6) NOT NULL,
  `city` varchar(50) NOT NULL,
  `country_id` smallint(6) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `city`
--

INSERT INTO `city` (`city_id`, `city`, `country_id`, `last_update`) VALUES
(300, 'Lethbridge', 20, '2006-02-14 21:45:25'),
(576, 'Woodridge', 8, '2006-02-14 21:45:25');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `country`
--

DROP TABLE IF EXISTS `country`;
CREATE TABLE `country` (
  `country_id` smallint(6) NOT NULL,
  `country` varchar(50) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `country`
--

INSERT INTO `country` (`country_id`, `country`, `last_update`) VALUES
(8, 'Australia', '2006-02-14 21:44:00'),
(20, 'Canada', '2006-02-14 21:44:00');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `staff`
--

DROP TABLE IF EXISTS `staff`;
CREATE TABLE `staff` (
  `staff_id` tinyint(4) NOT NULL,
  `first_name` varchar(45) NOT NULL,
  `last_name` varchar(45) NOT NULL,
  `address_id` smallint(6) NOT NULL,
  `email` varchar(50) DEFAULT NULL,
  `store_id` tinyint(4) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `username` varchar(16) NOT NULL,
  `password` varchar(40) DEFAULT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `staff`
--

INSERT INTO `staff` (`staff_id`, `first_name`, `last_name`, `address_id`, `email`, `store_id`, `active`, `username`, `password`, `last_update`) VALUES
(1, 'Mike', 'Hillyer', 3, 'Mike.Hillyer@sakilastaff.com', 1, 1, 'Mike', '8cb2237d0679ca88db6464eac60da96345513964', '2006-02-14 21:57:16'),
(2, 'Jon', 'Stephens', 4, 'Jon.Stephens@sakilastaff.com', 2, 1, 'Jon', '8cb2237d0679ca88db6464eac60da96345513964', '2006-02-14 21:57:16');

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `store`
--

DROP TABLE IF EXISTS `store`;
CREATE TABLE `store` (
  `store_id` tinyint(4) NOT NULL,
  `manager_staff_id` tinyint(4) NOT NULL,
  `address_id` smallint(6) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `store`
--

INSERT INTO `store` (`store_id`, `manager_staff_id`, `address_id`, `last_update`) VALUES
(1, 1, 1, '2006-02-14 21:57:12'),
(2, 2, 2, '2006-02-14 21:57:12');

--
-- Chỉ mục cho các bảng đã đổ
--

--
-- Chỉ mục cho bảng `address`
--
ALTER TABLE `address`
  ADD PRIMARY KEY (`address_id`);

--
-- Chỉ mục cho bảng `city`
--
ALTER TABLE `city`
  ADD PRIMARY KEY (`city_id`);

--
-- Chỉ mục cho bảng `country`
--
ALTER TABLE `country`
  ADD PRIMARY KEY (`country_id`);

--
-- Chỉ mục cho bảng `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`staff_id`);

--
-- Chỉ mục cho bảng `store`
--
ALTER TABLE `store`
  ADD PRIMARY KEY (`store_id`);

--
-- AUTO_INCREMENT cho các bảng đã đổ
--

--
-- AUTO_INCREMENT cho bảng `address`
--
ALTER TABLE `address`
  MODIFY `address_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT cho bảng `city`
--
ALTER TABLE `city`
  MODIFY `city_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=577;

--
-- AUTO_INCREMENT cho bảng `country`
--
ALTER TABLE `country`
  MODIFY `country_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT cho bảng `staff`
--
ALTER TABLE `staff`
  MODIFY `staff_id` tinyint(4) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT cho bảng `store`
--
ALTER TABLE `store`
  MODIFY `store_id` tinyint(4) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
