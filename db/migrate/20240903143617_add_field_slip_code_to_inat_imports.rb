class AddFieldSlipCodeToInatImports < ActiveRecord::Migration[7.1]
  def change
    add_column :inat_imports, :field_slip_code, :string
  end
end
