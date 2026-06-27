-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 18, 2026 at 04:51 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `sakila_hrm`
--

-- --------------------------------------------------------

--
-- Table structure for table `address`
--

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
-- Dumping data for table `address`
--

INSERT INTO `address` (`address_id`, `address`, `address2`, `district`, `city_id`, `postal_code`, `phone`, `last_update`) VALUES
(1, '47 MySakila Drive', NULL, ' ', 300, NULL, ' ', '2006-02-14 21:45:30'),
(2, '28 MySQL Boulevard', NULL, ' ', 576, NULL, ' ', '2006-02-14 21:45:30'),
(3, '23 Workhaven Lane', NULL, ' ', 300, NULL, ' ', '2006-02-14 21:45:30'),
(4, '1411 Lillydale Drive', NULL, ' ', 576, NULL, ' ', '2006-02-14 21:45:30');

-- --------------------------------------------------------

--
-- Table structure for table `city`
--

CREATE TABLE `city` (
  `city_id` smallint(6) NOT NULL,
  `city` varchar(50) NOT NULL,
  `country_id` smallint(6) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `city`
--

INSERT INTO `city` (`city_id`, `city`, `country_id`, `last_update`) VALUES
(300, 'Lethbridge', 20, '2006-02-14 21:45:25'),
(576, 'Woodridge', 8, '2006-02-14 21:45:25');

-- --------------------------------------------------------

--
-- Table structure for table `country`
--

CREATE TABLE `country` (
  `country_id` smallint(6) NOT NULL,
  `country` varchar(50) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `country`
--

INSERT INTO `country` (`country_id`, `country`, `last_update`) VALUES
(8, 'Australia', '2006-02-14 21:44:00'),
(20, 'Canada', '2006-02-14 21:44:00');

-- --------------------------------------------------------

--
-- Table structure for table `staff`
--

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
-- Dumping data for table `staff`
--

INSERT INTO `staff` (`staff_id`, `first_name`, `last_name`, `address_id`, `email`, `store_id`, `active`, `username`, `password`, `last_update`) VALUES
(1, 'Mike', 'Hillyer', 3, 'Mike.Hillyer@sakilastaff.com', 1, 1, 'Mike', '8cb2237d0679ca88db6464eac60da96345513964', '2006-02-14 21:57:16'),
(2, 'Jon', 'Stephens', 4, 'Jon.Stephens@sakilastaff.com', 2, 1, 'Jon', '8cb2237d0679ca88db6464eac60da96345513964', '2006-02-14 21:57:16');

-- --------------------------------------------------------

--
-- Table structure for table `store`
--

CREATE TABLE `store` (
  `store_id` tinyint(4) NOT NULL,
  `manager_staff_id` tinyint(4) NOT NULL,
  `address_id` smallint(6) NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `store`
--

INSERT INTO `store` (`store_id`, `manager_staff_id`, `address_id`, `last_update`) VALUES
(1, 1, 1, '2006-02-14 21:57:12'),
(2, 2, 2, '2006-02-14 21:57:12');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `address`
--
ALTER TABLE `address`
  ADD PRIMARY KEY (`address_id`);

--
-- Indexes for table `city`
--
ALTER TABLE `city`
  ADD PRIMARY KEY (`city_id`);

--
-- Indexes for table `country`
--
ALTER TABLE `country`
  ADD PRIMARY KEY (`country_id`);

--
-- Indexes for table `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`staff_id`);

--
-- Indexes for table `store`
--
ALTER TABLE `store`
  ADD PRIMARY KEY (`store_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `address`
--
ALTER TABLE `address`
  MODIFY `address_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `city`
--
ALTER TABLE `city`
  MODIFY `city_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=577;

--
-- AUTO_INCREMENT for table `country`
--
ALTER TABLE `country`
  MODIFY `country_id` smallint(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `staff`
--
ALTER TABLE `staff`
  MODIFY `staff_id` tinyint(4) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `store`
--
ALTER TABLE `store`
  MODIFY `store_id` tinyint(4) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
