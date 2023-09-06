# frozen_string_literal: true

class AddAcceptingObservationsToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column(:projects, :accepting_observations, :boolean,
               default: true, null: false)
  end
end
