# frozen_string_literal: true

class AddPlaceholderToObservations < ActiveRecord::Migration[7.2]
  def change
    add_column(:observations, :placeholder, :boolean,
               default: false, null: false)
  end
end
