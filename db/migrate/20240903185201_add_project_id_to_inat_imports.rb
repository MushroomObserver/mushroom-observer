class AddProjectIdToInatImports < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :project_id, :integer
  end
end
