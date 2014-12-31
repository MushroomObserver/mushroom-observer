class ChangeEnumColumnsToIntegers < ActiveRecord::Migration
  def up
    change_column :location_descriptions, :source_type, :integer
    change_column :name_descriptions, :review_status, :integer
    change_column_default :name_descriptions, :review_status, 0
    change_column :name_descriptions, :source_type, :integer
    change_column :names, :rank, :integer
    change_column :notifications, :flavor, :integer
    change_column :queries, :flavor, :integer
    change_column :queries, :model, :integer
    change_column :queries, :thumbnail_size, :integer
    change_column_default :queries, :thumbnail_size, 0
    change_column :queries, :image_size, :integer
    change_column_default :queries, :image_size, 0
    change_column :queries, :votes_anonymous, :integer
    change_column_default :queries, :votes_anonymous, 0
    change_column :queries, :location_format, :integer
    change_column_default :queries, :location_format, 0
  end

  def down
    change_column :location_descriptions, :source_type, :string, limit: 7
    change_column :name_descriptions, :review_status, :string, limit: 10
    change_column_default :name_descriptions, :review_status, "unreviewed"
    change_column :name_descriptions, :source_type, :string, limit: 7
    change_column :names, :rank, :string, limit: 10
    change_column :notifications, :flavor, :string, limit: 12
    change_column :queries, :flavor, :string, limit: 33
    change_column :queries, :model, :string, limit: 19
    change_column :queries, :thumbnail_size, :string, limit: 9
    change_column_default :queries, :thumbnail_size, "thumbnail"
    change_column :queries, :image_size, :string, limit: 9
    change_column_default :queries, :image_size, "medium"
    change_column :queries, :votes_anonymous, :string, limit: 3
    change_column_default :queries, :votes_anonymous, "no"
    change_column :queries, :location_format, :string, limit: 10
    change_column_default :queries, :location_format, "postal"
  end
end
