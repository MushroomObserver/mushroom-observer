class AddCancelToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :cancel, :boolean
  end
end
