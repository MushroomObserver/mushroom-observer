class RenameInatImportColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :inat_imports, :total_imports, :total_imported_count
    rename_column :inat_imports, :total_time, :total_seconds
  end
end
