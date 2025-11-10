class AddLastUserInputsToInatImports < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:inat_imports, :last_user_inputs)
      add_column :inat_imports, :last_user_inputs, :json
    end
  end
end
