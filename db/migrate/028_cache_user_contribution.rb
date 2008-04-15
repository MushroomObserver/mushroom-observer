class CacheUserContribution < ActiveRecord::Migration
  def self.up
    add_column :users, "contribution", :integer, :default => 0
    SiteData.new.get_all_user_data
  end

  def self.down
    remove_column :users, "contribution"
  end
end
