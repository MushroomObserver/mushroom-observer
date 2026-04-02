# frozen_string_literal: true

class ChangeImportOthersDefault < ActiveRecord::Migration[7.2]
  def change
    change_column_default(:inat_imports, :import_others, from: true, to: false)
  end
end
