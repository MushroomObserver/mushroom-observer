class AddTokenToInatImports < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :token, :string
  end
end
