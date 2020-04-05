# encoding: utf-8
class DefaultRssType < ActiveRecord::Migration[4.2]
  def self.up
    # Give user the ability to choose which RSS log type(s) they want to see by
    # default.  We will need to make this longer if we add more types, as 40
    # characters is just enough for "location name observation species_list".
    add_column :users, :default_rss_type, :string, default: "all", limit: 40
  end

  def self.down
    remove_column :users, :default_rss_type
  end
end
