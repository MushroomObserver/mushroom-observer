class AddInatUsernameToInatImports < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :inat_username, :string
  end
end
