SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

CREATE TABLE IF NOT EXISTS `formats` (
`id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `bitrate` float DEFAULT NULL,
  `codec` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `origins` (
`id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `title` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `recordings` (
`id` int(11) NOT NULL,
  `origin` int(11) DEFAULT NULL,
  `rec_start` timestamp NULL DEFAULT NULL,
  `rec_end` timestamp NULL DEFAULT NULL,
  `status` enum('prepared','recording','indexing','recorded') NOT NULL DEFAULT 'prepared',
  `previous_id` int(11) DEFAULT NULL,
  `next_id` int(11) DEFAULT NULL,
  `temp_dir` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `rec_files` (
`id` int(11) NOT NULL,
  `recording_id` int(11) NOT NULL,
  `format_id` int(11) NOT NULL,
  `ready` tinyint(1) NOT NULL DEFAULT '0',
  `filename` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


ALTER TABLE `formats`
 ADD PRIMARY KEY (`id`);

ALTER TABLE `origins`
 ADD PRIMARY KEY (`id`);

ALTER TABLE `recordings`
 ADD PRIMARY KEY (`id`);

ALTER TABLE `rec_files`
 ADD PRIMARY KEY (`id`);


ALTER TABLE `formats`
MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `origins`
MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `recordings`
MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `rec_files`
MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
