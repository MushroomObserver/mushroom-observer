class ChangeEnumColumnsToIntegers < ActiveRecord::Migration[4.2]
  def up
    change_column :location_descriptions, :source_type, :integer
    change_column :name_descriptions, :review_status, :integer, default: 0
    change_column :name_descriptions, :source_type, :integer
    change_column :names, :rank, :integer
    change_column :names_versions, :rank, :integer
    change_column :notifications, :flavor, :integer
    change_column :queries, :flavor, :integer
    change_column :queries, :model, :integer
    change_column :users, :thumbnail_size, :integer, default: 0
    change_column :users, :image_size, :integer, default: 0
    change_column :users, :votes_anonymous, :integer, default: 0
    change_column :users, :location_format, :integer, default: 0
    change_column :users, :hide_authors, :integer, default: 0
    change_column :users, :keep_filenames, :integer, default: 0
  end

  def down
    change_column :location_descriptions, :source_type, :string, limit: 7
    change_column :name_descriptions, :review_status, :string, limit: 10, default: "unreviewed"
    change_column :name_descriptions, :source_type, :string, limit: 7
    change_column :names, :rank, :string, limit: 10
    change_column :names_versions, :rank, :string, limit: 10
    change_column :notifications, :flavor, :string, limit: 12
    change_column :queries, :flavor, :string, limit: 33
    change_column :queries, :model, :string, limit: 19
    change_column :users, :thumbnail_size, :string, limit: 9, default: "thumbnail"
    change_column :users, :image_size, :string, limit: 9, default: "medium"
    change_column :users, :votes_anonymous, :string, limit: 3, default: "no"
    change_column :users, :location_format, :string, limit: 10, default: "postal"
    change_column :users, :hide_authors, :string, limit: 13, default: "none"
    change_column :users, :keep_filenames, :string, limit: 13, default: "keep_and_show"
  end
end
