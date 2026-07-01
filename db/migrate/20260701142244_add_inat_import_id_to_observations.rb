# frozen_string_literal: true

class AddInatImportIdToObservations < ActiveRecord::Migration[7.2]
  def change
    change_table(:observations, bulk: true) do |t|
      t.integer(:inat_import_id)
      t.index(:inat_import_id)
    end
  end
end
