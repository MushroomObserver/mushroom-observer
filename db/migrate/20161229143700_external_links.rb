class ExternalLinks < ActiveRecord::Migration[4.2]
  def self.up
    create_table :external_sites, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string   "name",       limit: 100
      t.integer  "project_id", limit: 4
    end

    create_table :external_links, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id",          limit: 4
      t.integer  "observation_id",   limit: 4
      t.integer  "external_site_id", limit: 4
      t.string   "url",              limit: 100
    end
  end

  def self.down
    drop_table :external_sites
    drop_table :external_links
  end
end
