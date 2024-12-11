class RemoveMycoportalDbFromHerbaria < ActiveRecord::Migration[7.1]
  def change
    remove_column :herbaria, :mycoportal_db, :string
  end
end
