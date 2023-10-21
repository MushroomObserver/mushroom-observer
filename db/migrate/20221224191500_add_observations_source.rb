# frozen_string_literal: true

class AddObservationsSource < ActiveRecord::Migration[6.1]
  def change
    add_column(:observations, :source, :integer, default: nil, null: true)
  end
end
