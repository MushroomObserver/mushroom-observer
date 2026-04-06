# frozen_string_literal: true

class RenameDefaultObservationToPrimaryObservation < ActiveRecord::Migration[7.2]
  def change
    rename_column(:occurrences,
                  :default_observation_id, :primary_observation_id)
  end
end
