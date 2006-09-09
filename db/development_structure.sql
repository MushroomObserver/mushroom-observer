CREATE TABLE `comments` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `user_id` int(11) default NULL,
  `summary` varchar(100) default NULL,
  `comment` text,
  `observation_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `images` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `content_type` varchar(100) default NULL,
  `title` varchar(100) default NULL,
  `user_id` int(11) default NULL,
  `when` date default NULL,
  `notes` text,
  `copyright_holder` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `images_observations` (
  `image_id` int(11) NOT NULL default '0',
  `observation_id` int(11) NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `observations` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `when` date default NULL,
  `user_id` int(11) default NULL,
  `where` varchar(100) default NULL,
  `what` varchar(100) default NULL,
  `specimen` tinyint(1) NOT NULL default '0',
  `notes` text,
  `thumb_image_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `observations_species_lists` (
  `observation_id` int(11) NOT NULL default '0',
  `species_list_id` int(11) NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `rss_logs` (
  `id` int(11) NOT NULL auto_increment,
  `observation_id` int(11) default NULL,
  `species_list_id` int(11) default NULL,
  `modified` datetime default NULL,
  `notes` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `schema_info` (
  `version` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `species_lists` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `when` date default NULL,
  `user_id` int(11) default NULL,
  `where` varchar(100) default NULL,
  `title` varchar(100) default NULL,
  `notes` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
  `id` int(11) NOT NULL auto_increment,
  `login` varchar(80) NOT NULL default '',
  `password` varchar(40) NOT NULL default '',
  `email` varchar(80) NOT NULL default '',
  `theme` varchar(40) default NULL,
  `name` varchar(80) default NULL,
  `created` datetime default NULL,
  `last_login` datetime default NULL,
  `verified` datetime default NULL,
  `feature_email` tinyint(1) NOT NULL default '1',
  `commercial_email` tinyint(1) NOT NULL default '1',
  `question_email` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO schema_info (version) VALUES (9)