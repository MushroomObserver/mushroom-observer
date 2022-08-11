class AddPrimaryKeyToCollectionNumbersObservations < ActiveRecord::Migration[6.1]
  def change
    rename_table(
      "collection_numbers_observations", "observation_collection_numbers"
    )
    add_column(:observation_collection_numbers, :id, :primary_key)
  end
end
