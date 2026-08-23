# frozen_string_literal: true

class AddInatStandInNamingIDToObservations < ActiveRecord::Migration[7.2]
  def change
    add_column(:observations, :inat_stand_in_naming_id, :integer)
  end
end
