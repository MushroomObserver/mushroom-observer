class RefactorQuery < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :queries
    create_table :query_records, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.datetime "updated_at"
      t.integer  "access_count", limit: 4
      t.text     "description",  limit: 65535
      t.integer  "outer_id",     limit: 4
    end
  end

  def self.down
    drop_table :query_records
    create_table :queries, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.datetime "updated_at"
      t.integer  "access_count", limit: 4
      t.text     "params",       limit: 65535
      t.integer  "outer_id",     limit: 4
      t.integer  "flavor",       limit: 4
      t.integer  "model",        limit: 4
    end
  end
end
