#!/usr/local/bin/ruby

require "rubygems" 
require_gem "activerecord" 
require "digest/sha1"

$config = YAML.load_file(File.join(File.dirname(__FILE__), '/home/velosa/mushroomobserver.org/config/database.yml'))

class User < ActiveRecord::Base
  establish_connection $config['test']

  def change_password(pass)
    if pass != ''
      update_attribute "password", self.class.sha1(pass)
    end
  end
  
  protected

  def self.sha1(pass)
    # Digest::SHA1.hexdigest("change-me--#{pass}--")
    Digest::SHA1.hexdigest("something__#{pass}__")
  end
    
end


test_db = $config["test"]
src_db = $config["production"]
system("mysqldump -u %s -p%s %s | mysql -u %s -p%s %s" %
       [src_db["username"], src_db["password"], src_db["database"],
        test_db["username"], test_db["password"], test_db["database"]])

for user in User.find(:all)
  user.email = ''
  user.change_password('password')
  user.save
end

system("mysqldump -u %s -p%s %s > /home/velosa/mushroomobserver.org/public/safe.dump" %
       [test_db["username"], test_db["password"], test_db["database"]])
