class AddImportablesAndImportedCountToInatImport < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :importables, :integer
    add_column :inat_imports, :imported_count, :integer
  end
end
