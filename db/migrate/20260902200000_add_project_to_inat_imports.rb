# frozen_string_literal: true

class AddProjectToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :project_id, :integer)
    add_column(:inat_imports, :constraint_violation_obs_ids, :text)
    add_column(:inat_imports, :unlicensed_image_events, :text)
  end
end
