class AddPrimaryKeyToHerbariaCurators < ActiveRecord::Migration[6.1]
  def change
    rename_table("herbaria_curators", "herbarium_curators")
    add_column(:herbarium_curators, :id, :primary_key)
  end
end
