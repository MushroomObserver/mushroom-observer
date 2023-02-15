class AddIndexToNamingsObservationId < ActiveRecord::Migration[6.1]
  def change
    add_index :namings, :observation_id, unique: true
  end
end
