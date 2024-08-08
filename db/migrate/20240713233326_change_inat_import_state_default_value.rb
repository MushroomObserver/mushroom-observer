class ChangeInatImportStateDefaultValue < ActiveRecord::Migration[7.1]
  def change
    change_column_default :inat_imports, :state, from: nil, to: 0
  end
end
