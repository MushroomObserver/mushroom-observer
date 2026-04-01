# frozen_string_literal: true

class AddOwnObservationsToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :own_observations, :boolean,
               default: true, null: false)
  end
end
