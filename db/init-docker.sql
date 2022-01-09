drop database if exists mo_development;
create database mo_development
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;
drop database if exists mo_test;
create database mo_test
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;
drop database if exists mo_tmp;
create database mo_tmp;
use mo_tmp;

drop procedure if exists createUser;
delimiter $$
create procedure createUser(username varchar(50), pw varchar(50))
begin
IF (SELECT EXISTS(SELECT 1 FROM `mysql`.`user` WHERE `user` = username)) = 0 THEN
    begin
    set @sql = CONCAT('CREATE USER ', username, '@\'%\' IDENTIFIED BY \'', pw, '\'');
    prepare stmt from @sql;
    execute stmt;
    deallocate prepare stmt;
    end;
END IF;
end $$
delimiter ;

call createUser('mo', 'mo');
use mo_test;
drop database mo_tmp;

grant all privileges on mo_development.* to 'mo'@'%' with grant option;
grant all privileges on mo_test.* to 'mo'@'%' with grant option;
