# frozen_string_literal: true

class AddLocationToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column(:projects, :location_id, :integer)
  end
end
