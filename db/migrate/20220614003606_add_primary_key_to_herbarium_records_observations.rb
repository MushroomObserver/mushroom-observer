class AddPrimaryKeyToHerbariumRecordsObservations < ActiveRecord::Migration[6.1]
  def change
    rename_table(
      "herbarium_records_observations", "observation_herbarium_records"
    )
    add_column(:observation_herbarium_records, :id, :primary_key)
  end
end
