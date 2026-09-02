# frozen_string_literal: true

class AddSkeletonImportFieldsToInatImports < ActiveRecord::Migration[7.2]
  def change
    change_table(:inat_imports, bulk: true) do |t|
      t.column(:create_skeletons, :boolean, default: true, null: false)
      t.column(:skeleton_imported_count, :integer, default: 0, null: false)
      t.column(:skeleton_observation_ids, :text)
    end
  end
end
