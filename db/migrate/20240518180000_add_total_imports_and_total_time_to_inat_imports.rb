class AddTotalImportsAndTotalTimeToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :total_imports, :integer
    add_column :inat_imports, :total_time, :integer
  end
end
