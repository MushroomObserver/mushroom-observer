# frozen_string_literal: true

class AddActionableInatIdColumnsToInatImports < ActiveRecord::Migration[7.2]
  def change
    change_table(:inat_imports, bulk: true) do |t|
      t.column(:date_missing_inat_ids, :text)
      t.column(:license_added_inat_ids, :text)
    end
  end
end
