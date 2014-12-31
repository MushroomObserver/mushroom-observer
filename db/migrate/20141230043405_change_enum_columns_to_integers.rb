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
  end

  def down
    change_column :location_descriptions, :source_type, :string, limit: 7
    change_column :name_descriptions, :review_status, :string, limit: 10
    change_column_default :name_descriptions, :review_status, "unreviewed"
    change_column :name_descriptions, :source_type, :string, limit: 7
    change_column :names, :rank, :string, limit: 10
    change_column :notifications, :flavor, :string, limit: 12
    change_column :queries, :flavor, :integer, limit: 33
    change_column :queries, :model, :integer, limit: 19
  end
end
