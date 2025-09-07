class RemoveExportAllFromInatExports < ActiveRecord::Migration[7.2]
  def change
    remove_column :inat_exports, :export_all, :boolean
  end
end
