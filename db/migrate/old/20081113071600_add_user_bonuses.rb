class AddUserBonuses < ActiveRecord::Migration
  def self.up
    add_column :users, "bonuses", :text
  end

  def self.down
    remove_column :users, "bonuses"
  end
end
