class RemoveMergeSourceId < ActiveRecord::Migration[6.1]
  def change
    remove_column :location_descriptions, :merge_source_id, :integer
    remove_column :name_descriptions, :merge_source_id, :integer
  end
end
