class VersionedTerms < ActiveRecord::Migration
  def self.up
    drop_table :terms
    create_table :terms, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.integer 'version'
      t.integer 'user_id'
      t.string "name", :limit => 1024
      t.integer "thumb_image_id"
      t.text "description"
      t.timestamps
    end

    create_table :images_terms, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.integer 'image_id'
      t.integer 'term_id'
    end
    
    create_table :terms_versions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.integer 'term_id'
      t.integer 'version'
      t.integer 'user_id'
      t.datetime 'updated_at'
      t.string "name", :limit => 1024
      t.text "description"
    end

    rename_column :comments, :modified, :updated_at
    rename_column :copyright_changes, :modified, :updated_at
    rename_column :images, :modified, :updated_at
    rename_column :interests, :modified, :updated_at
    rename_column :licenses, :modified, :updated_at
    rename_column :location_descriptions, :modified, :updated_at
    rename_column :location_descriptions_versions, :modified, :updated_at
    rename_column :locations, :modified, :updated_at
    rename_column :locations_versions, :modified, :updated_at
    rename_column :name_descriptions, :modified, :updated_at
    rename_column :name_descriptions_versions, :modified, :updated_at
    rename_column :names, :modified, :updated_at
    rename_column :names_versions, :modified, :updated_at
    rename_column :namings, :modified, :updated_at
    rename_column :notifications, :modified, :updated_at
    rename_column :observations, :modified, :updated_at
    rename_column :projects, :modified, :updated_at
    rename_column :queries, :modified, :updated_at
    rename_column :rss_logs, :modified, :updated_at
    rename_column :species_lists, :modified, :updated_at
    rename_column :transactions, :modified, :updated_at
    rename_column :translation_strings, :modified, :updated_at
    rename_column :translation_strings_versions, :modified, :updated_at
    rename_column :user_groups, :modified, :updated_at
    rename_column :users, :modified, :updated_at
    rename_column :votes, :modified, :updated_at
    rename_column :api_keys, :created, :created_at
    rename_column :comments, :created, :created_at
    rename_column :images, :created, :created_at
    rename_column :location_descriptions, :created, :created_at
    rename_column :locations, :created, :created_at
    rename_column :name_descriptions, :created, :created_at
    rename_column :names, :created, :created_at
    rename_column :namings, :created, :created_at
    rename_column :observations, :created, :created_at
    rename_column :projects, :created, :created_at
    rename_column :species_lists, :created, :created_at
    rename_column :user_groups, :created, :created_at
    rename_column :users, :created, :created_at
    rename_column :votes, :created, :created_at
  end

  def self.down
    rename_column :comments, :updated_at, :modified
    rename_column :copyright_changes, :updated_at, :modified
    rename_column :images, :updated_at, :modified
    rename_column :interests, :updated_at, :modified
    rename_column :licenses, :updated_at, :modified
    rename_column :location_descriptions, :updated_at, :modified
    rename_column :location_descriptions_versions, :updated_at, :modified
    rename_column :locations, :updated_at,  :modified
    rename_column :locations_versions, :updated_at,  :modified
    rename_column :name_descriptions, :updated_at, :modified
    rename_column :name_descriptions_versions, :updated_at, :modified
    rename_column :names, :updated_at, :modified
    rename_column :names_versions, :updated_at, :modified
    rename_column :namings, :updated_at, :modified
    rename_column :notifications, :updated_at, :modified
    rename_column :observations, :updated_at, :modified
    rename_column :projects, :updated_at, :modified
    rename_column :queries, :updated_at, :modified
    rename_column :rss_logs, :updated_at, :modified
    rename_column :species_lists, :updated_at, :modified
    rename_column :transactions, :updated_at, :modified
    rename_column :translation_strings, :updated_at, :modified
    rename_column :translation_strings_versions, :updated_at, :modified
    rename_column :user_groups, :updated_at, :modified
    rename_column :users, :updated_at, :modified
    rename_column :votes, :updated_at, :modified
    rename_column :api_keys, :created_at, :created
    rename_column :comments, :created_at, :created
    rename_column :images, :created_at, :created
    rename_column :location_descriptions, :created_at, :created
    rename_column :locations, :created_at, :created
    rename_column :name_descriptions, :created_at, :created
    rename_column :names, :created_at, :created
    rename_column :namings, :created_at, :created
    rename_column :observations, :created_at, :created
    rename_column :projects, :created_at, :created
    rename_column :species_lists, :created_at, :created
    rename_column :user_groups, :created_at, :created
    rename_column :users, :created_at, :created
    rename_column :votes, :created_at, :created

    drop_table :terms
    create_table :terms do |t|
      t.string "name", :limit => 1024
      t.text "description"
      t.integer "image_id"
      t.timestamps
    end
    drop_table :images_terms
    drop_table :terms_versions
  end
end
