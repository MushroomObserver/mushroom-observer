create database mo_development;
create database mo_test;
create user 'mo'@'localhost' identified by 'mo';
grant all privileges on mo_development.* to 'mo'@'localhost' with grant option;
grant all privileges on mo_test.* to 'mo'@'localhost' with grant option;
