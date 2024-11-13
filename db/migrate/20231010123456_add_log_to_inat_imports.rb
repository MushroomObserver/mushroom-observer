class AddLogToInatImports < ActiveRecord::Migration[6.1]
  def change
    add_column :inat_imports, :log, :text
  end
end
