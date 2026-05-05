# frozen_string_literal: true

# Drop the `observations.classification` denormalized cache. Clade
# membership now reads from `names.classification` (a smaller column,
# scanned ~5-9× faster — see discussion #4163). The column had one
# reader (`Observation#one_clade`) and a fan-out cache callback
# (`Name#update_observation_cache`), both removed in the prior commit.
class RemoveClassificationFromObservations < ActiveRecord::Migration[7.2]
  def change
    remove_column(:observations, :classification, :text)
  end
end
