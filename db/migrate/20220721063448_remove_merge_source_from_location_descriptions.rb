class RemoveMergeSourceFromLocationDescriptions < ActiveRecord::Migration[6.1]
  def change
    remove_column :location_descriptions, :merge_source_id, :integer
  end
end
