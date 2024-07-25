class AddImportAllToInatImports < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :import_all, :boolean
  end
end
