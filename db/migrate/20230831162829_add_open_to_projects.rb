class AddOpenToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :open, :boolean, default: false, null: false
  end
end
