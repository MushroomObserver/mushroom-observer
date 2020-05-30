class ConvertYourDatabase < ActiveRecord::Migration[4.2]
  def self.up
    puts %(

      ************** You must convert your database! **************

      1. cc -o convert_old_database script/convert_old_database.c
      2. mysqldump -u mo -p mo_development > database.old
      3. cat database.old | ./convert_old_database > database.new
      4. mysql -u mo -p mo_development -e 'source database.new'

      *************************************************************

    )
  end

  def self.down
  end
end
