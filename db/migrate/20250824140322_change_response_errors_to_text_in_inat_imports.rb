class ChangeResponseErrorsToTextInInatImports < ActiveRecord::Migration[7.2]
  def change
    change_column :inat_imports, :response_errors, :text
  end
end
