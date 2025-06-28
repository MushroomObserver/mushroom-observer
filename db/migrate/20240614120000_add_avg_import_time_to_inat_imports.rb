class AddAvgImportTimeToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :avg_import_time, :float
  end
end
