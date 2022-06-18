class AddPrimaryKeyToObservationsSpeciesLists < ActiveRecord::Migration[6.1]
  def change
    rename_table("observations_species_lists", "species_list_observations")
    add_column(:species_list_observations, :id, :primary_key)
  end
end
