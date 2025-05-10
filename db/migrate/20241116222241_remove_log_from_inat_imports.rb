class RemoveLogFromInatImports < ActiveRecord::Migration[7.1]
  def change
    remove_column :inat_imports, :log, :text
  end
end
