# frozen_string_literal: true

# visual_group_images has no indexes. Every lookup by visual_group_id
# (Image.visual_groups/visual_group_included/visual_group_unreviewed)
# or by image_id (the join the other direction) is a full table scan.
class AddIndexesToVisualGroupImages < ActiveRecord::Migration[7.2]
  def change
    change_table(:visual_group_images, bulk: true) do |t|
      t.index([:visual_group_id, :included])
      t.index(:image_id)
    end
  end
end
