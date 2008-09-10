CREATE TABLE `add_image_test_logs` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) default NULL,
  `created_at` datetime default NULL,
  `upload_start` datetime default NULL,
  `upload_data_start` datetime default NULL,
  `upload_end` datetime default NULL,
  `image_count` int(11) default NULL,
  `image_bytes` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

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
  `license_id` int(11) NOT NULL default '1',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `images_observations` (
  `image_id` int(11) NOT NULL default '0',
  `observation_id` int(11) NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `licenses` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(80) default NULL,
  `url` varchar(200) default NULL,
  `deprecated` tinyint(1) NOT NULL default '0',
  `form_name` varchar(20) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `locations` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `user_id` int(11) NOT NULL default '0',
  `version` int(11) NOT NULL default '0',
  `display_name` varchar(200) default NULL,
  `notes` text,
  `north` float default NULL,
  `south` float default NULL,
  `west` float default NULL,
  `east` float default NULL,
  `high` float default NULL,
  `low` float default NULL,
  `search_name` varchar(200) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `names` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `user_id` int(11) NOT NULL default '0',
  `version` int(11) NOT NULL default '0',
  `text_name` varchar(100) default NULL,
  `author` varchar(100) default NULL,
  `display_name` varchar(200) default NULL,
  `observation_name` varchar(200) default NULL,
  `search_name` varchar(200) default NULL,
  `notes` text,
  `synonym_id` int(11) default NULL,
  `deprecated` tinyint(1) NOT NULL default '0',
  `rank` enum('Form','Variety','Subspecies','Species','Genus','Family','Order','Class','Phylum','Kingdom','Group') default NULL,
  `citation` varchar(200) default NULL,
  `gen_desc` text,
  `diag_desc` text,
  `distribution` text,
  `habitat` text,
  `look_alikes` text,
  `uses` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `naming_reasons` (
  `id` int(11) NOT NULL auto_increment,
  `naming_id` int(11) default NULL,
  `reason` int(11) default NULL,
  `notes` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `namings` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `observation_id` int(11) default NULL,
  `name_id` int(11) default NULL,
  `user_id` int(11) default NULL,
  `vote_cache` float default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL default '0',
  `flavor` enum('name','observation','user','all_comments') default NULL,
  `obj_id` int(11) default NULL,
  `note_template` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `observations` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `when` date default NULL,
  `user_id` int(11) default NULL,
  `where` varchar(100) default NULL,
  `specimen` tinyint(1) NOT NULL default '0',
  `notes` text,
  `thumb_image_id` int(11) default NULL,
  `name_id` int(11) default NULL,
  `location_id` int(11) default NULL,
  `is_collection_location` tinyint(1) NOT NULL default '1',
  `vote_cache` float default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `observations_species_lists` (
  `observation_id` int(11) NOT NULL default '0',
  `species_list_id` int(11) NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `past_locations` (
  `id` int(11) NOT NULL auto_increment,
  `location_id` int(11) default NULL,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `user_id` int(11) NOT NULL default '0',
  `version` int(11) NOT NULL default '0',
  `display_name` varchar(200) default NULL,
  `notes` text,
  `north` float default NULL,
  `south` float default NULL,
  `west` float default NULL,
  `east` float default NULL,
  `high` float default NULL,
  `low` float default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `past_names` (
  `id` int(11) NOT NULL auto_increment,
  `name_id` int(11) default NULL,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `user_id` int(11) NOT NULL default '0',
  `version` int(11) NOT NULL default '0',
  `text_name` varchar(100) default NULL,
  `author` varchar(100) default NULL,
  `display_name` varchar(200) default NULL,
  `observation_name` varchar(200) default NULL,
  `search_name` varchar(200) default NULL,
  `notes` text,
  `deprecated` tinyint(1) NOT NULL default '0',
  `citation` varchar(200) default NULL,
  `rank` enum('Form','Variety','Subspecies','Species','Genus','Family','Order','Class','Phylum','Kingdom','Group') default NULL,
  `gen_desc` text,
  `diag_desc` text,
  `distribution` text,
  `habitat` text,
  `look_alikes` text,
  `uses` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `queued_email_integers` (
  `id` int(11) NOT NULL auto_increment,
  `queued_email_id` int(11) NOT NULL default '0',
  `key` varchar(100) default NULL,
  `value` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `queued_email_notes` (
  `id` int(11) NOT NULL auto_increment,
  `queued_email_id` int(11) NOT NULL default '0',
  `value` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `queued_email_strings` (
  `id` int(11) NOT NULL auto_increment,
  `queued_email_id` int(11) NOT NULL default '0',
  `key` varchar(100) default NULL,
  `value` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `queued_emails` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) default NULL,
  `to_user_id` int(11) NOT NULL default '0',
  `queued` datetime default NULL,
  `flavor` enum('comment','feature','naming') default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `rss_logs` (
  `id` int(11) NOT NULL auto_increment,
  `observation_id` int(11) default NULL,
  `species_list_id` int(11) default NULL,
  `modified` datetime default NULL,
  `notes` text,
  `name_id` int(11) default NULL,
  `synonym_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL default '',
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `search_states` (
  `id` int(11) NOT NULL auto_increment,
  `timestamp` datetime default NULL,
  `access_count` int(11) default NULL,
  `query_type` varchar(20) default NULL,
  `title` varchar(100) default NULL,
  `conditions` text,
  `order` text,
  `source` varchar(20) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `sequence_states` (
  `id` int(11) NOT NULL auto_increment,
  `timestamp` datetime default NULL,
  `access_count` int(11) default NULL,
  `query_type` varchar(20) default NULL,
  `query` text,
  `current_id` int(11) default NULL,
  `current_index` int(11) default NULL,
  `prev_id` int(11) default NULL,
  `next_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

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

CREATE TABLE `synonyms` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
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
  `rows` int(11) default NULL,
  `columns` int(11) default NULL,
  `alternate_rows` tinyint(1) NOT NULL default '1',
  `alternate_columns` tinyint(1) NOT NULL default '1',
  `vertical_layout` tinyint(1) NOT NULL default '1',
  `license_id` int(11) NOT NULL default '3',
  `comment_email` tinyint(1) NOT NULL default '1',
  `html_email` tinyint(1) NOT NULL default '1',
  `contribution` int(11) default '0',
  `notes` text NOT NULL,
  `location_id` int(11) default NULL,
  `image_id` int(11) default NULL,
  `mailing_address` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `votes` (
  `id` int(11) NOT NULL auto_increment,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `naming_id` int(11) default NULL,
  `user_id` int(11) default NULL,
  `value` int(11) default NULL,
  `observation_id` int(11) default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO schema_migrations (version) VALUES ('1');

INSERT INTO schema_migrations (version) VALUES ('10');

INSERT INTO schema_migrations (version) VALUES ('11');

INSERT INTO schema_migrations (version) VALUES ('12');

INSERT INTO schema_migrations (version) VALUES ('13');

INSERT INTO schema_migrations (version) VALUES ('14');

INSERT INTO schema_migrations (version) VALUES ('15');

INSERT INTO schema_migrations (version) VALUES ('16');

INSERT INTO schema_migrations (version) VALUES ('17');

INSERT INTO schema_migrations (version) VALUES ('18');

INSERT INTO schema_migrations (version) VALUES ('19');

INSERT INTO schema_migrations (version) VALUES ('2');

INSERT INTO schema_migrations (version) VALUES ('20');

INSERT INTO schema_migrations (version) VALUES ('20080909042002');

INSERT INTO schema_migrations (version) VALUES ('21');

INSERT INTO schema_migrations (version) VALUES ('22');

INSERT INTO schema_migrations (version) VALUES ('23');

INSERT INTO schema_migrations (version) VALUES ('24');

INSERT INTO schema_migrations (version) VALUES ('25');

INSERT INTO schema_migrations (version) VALUES ('26');

INSERT INTO schema_migrations (version) VALUES ('27');

INSERT INTO schema_migrations (version) VALUES ('28');

INSERT INTO schema_migrations (version) VALUES ('29');

INSERT INTO schema_migrations (version) VALUES ('3');

INSERT INTO schema_migrations (version) VALUES ('30');

INSERT INTO schema_migrations (version) VALUES ('31');

INSERT INTO schema_migrations (version) VALUES ('32');

INSERT INTO schema_migrations (version) VALUES ('33');

INSERT INTO schema_migrations (version) VALUES ('34');

INSERT INTO schema_migrations (version) VALUES ('35');

INSERT INTO schema_migrations (version) VALUES ('4');

INSERT INTO schema_migrations (version) VALUES ('5');

INSERT INTO schema_migrations (version) VALUES ('6');

INSERT INTO schema_migrations (version) VALUES ('7');

INSERT INTO schema_migrations (version) VALUES ('8');

INSERT INTO schema_migrations (version) VALUES ('9');