# frozen_string_literal: true

class AddTotalImportablesToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :total_importables, :integer)
  end
end
