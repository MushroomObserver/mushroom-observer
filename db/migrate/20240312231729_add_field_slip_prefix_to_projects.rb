class AddFieldSlipPrefixToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :field_slip_prefix, :string
    add_index(:projects, :field_slip_prefix, unique: true)
  end
end
