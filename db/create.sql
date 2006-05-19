CREATE TABLE `images` (
  `id` int(11) NOT NULL auto_increment,
  `content_type` varchar(100) default NULL,
  `title` varchar(100) default NULL,
  `owner` varchar(100) default NULL,
  `when` date default NULL,
  `notes` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `images_observations` (
  `image_id` int(11) NOT NULL default '0',
  `observation_id` int(11) NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `observations` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `when` date default NULL,
  `who` varchar(100) default NULL,
  `where` varchar(100) default NULL,
  `what` varchar(100) default NULL,
  `image_name` varchar(200) default NULL,
  `specimen` tinyint(1) NOT NULL default '0',
  `notes` text,
  `thumb_image_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
