class AddDatesToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :start_date, :date, null: true, default: nil
    add_column :projects, :end_date, :date, null: true, default: nil
  end
end
