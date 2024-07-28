class RenameLicenseFormNameToCode < ActiveRecord::Migration[7.1]
  def change
    rename_column(:licenses, :form_name, :code)
  end
end
