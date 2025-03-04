class AddResponseErrorsToInatImport < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :response_errors, :string
  end
end
