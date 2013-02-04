drop database if exists mo_development;
create database mo_development;
drop database if exists mo_test;
create database mo_test;
	
drop procedure if exists createUser;
delimiter $$
create procedure createUser(username varchar(50), pw varchar(50))
begin
IF (SELECT EXISTS(SELECT 1 FROM `mysql`.`user` WHERE `user` = username)) = 0 THEN
    begin
    set @sql = CONCAT('CREATE USER ', username, '@\'localhost\' IDENTIFIED BY \'', pw, '\'');
    prepare stmt from @sql;
    execute stmt;
    deallocate prepare stmt;
    end;
END IF;
end $$
delimiter ;

call createUser('mo', 'mo')

grant all privileges on mo_development.* to 'mo'@'localhost' with grant option;
grant all privileges on mo_test.* to 'mo'@'localhost' with grant option;
