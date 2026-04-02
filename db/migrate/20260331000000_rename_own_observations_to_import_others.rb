# frozen_string_literal: true

class RenameOwnObservationsToImportOthers < ActiveRecord::Migration[7.2]
  def change
    rename_column :inat_imports, :own_observations, :import_others
  end
end
