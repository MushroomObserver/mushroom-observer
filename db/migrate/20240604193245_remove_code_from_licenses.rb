class RemoveCodeFromLicenses < ActiveRecord::Migration[7.1]
  def change
    remove_column :licenses, :code, :string
  end
end
