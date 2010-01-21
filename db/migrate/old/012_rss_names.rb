class RssNames < ActiveRecord::Migration
  def self.up
    add_column :rss_logs,  "name_id", :integer
  end

  def self.down
    remove_column :rss_logs,  "name_id"
  end
end
