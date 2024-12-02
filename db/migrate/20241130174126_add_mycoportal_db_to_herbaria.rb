class AddMycoportalDbToHerbaria < ActiveRecord::Migration[7.1]
  def change
    add_column :herbaria, :mycoportal_db, :integer
  end
end
