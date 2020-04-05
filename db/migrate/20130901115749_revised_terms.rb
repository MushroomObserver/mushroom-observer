class RevisedTerms < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :terms
    create_table :terms, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer "version"
      t.integer "user_id"
      t.string "name", limit: 1024
      t.integer "thumb_image_id"
      t.text "description"
      t.integer "rss_log_id"
      t.timestamps
    end

    create_table :images_terms, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", id: false, force: true do |t|
      t.integer "image_id"
      t.integer "term_id"
    end

    create_table :terms_versions, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer "term_id"
      t.integer "version"
      t.integer "user_id"
      t.datetime "updated_at"
      t.string "name", limit: 1024
      t.text "description"
    end

    add_column :rss_logs, :term_id, :integer
  end

  def self.down
    remove_column :rss_logs, :term_id
    drop_table :terms
    create_table :terms do |t|
      t.string "name", limit: 1024
      t.text "description"
      t.integer "image_id"
      t.timestamps
    end
    drop_table :images_terms
    drop_table :terms_versions
  end
end
