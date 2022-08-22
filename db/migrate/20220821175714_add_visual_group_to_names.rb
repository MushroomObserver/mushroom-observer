class AddVisualGroupToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :visual_group_id, :integer
    add_column :names_versions, :visual_group_id, :integer
  end
end
