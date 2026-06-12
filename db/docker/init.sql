-- Docker MariaDB init: create additional databases and grant permissions.
-- MYSQL_DATABASE/MYSQL_USER/MYSQL_PASSWORD in compose.yaml create mo_development
-- and the mo user automatically; this script handles the rest.

CREATE DATABASE IF NOT EXISTS cache_development
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;

CREATE DATABASE IF NOT EXISTS mo_test
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;

GRANT ALL PRIVILEGES ON `mo_development`.* TO 'mo'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `cache_development`.* TO 'mo'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `mo_test`.* TO 'mo'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `mo_test-%`.* TO 'mo'@'%';
GRANT CREATE ON *.* TO 'mo'@'%';
FLUSH PRIVILEGES;
