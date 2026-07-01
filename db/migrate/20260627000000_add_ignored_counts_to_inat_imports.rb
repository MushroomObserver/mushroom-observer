# frozen_string_literal: true

class AddIgnoredCountsToInatImports < ActiveRecord::Migration[7.2]
  def change
    change_table(:inat_imports, bulk: true) do |t|
      t.integer(:ignored_not_importable_count, default: 0, null: false)
      t.integer(:ignored_date_missing_count, default: 0, null: false)
      t.integer(:ignored_already_imported_count, default: 0, null: false)
    end
  end
end
