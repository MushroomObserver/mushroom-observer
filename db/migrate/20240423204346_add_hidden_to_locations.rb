# frozen_string_literal: true

class AddHiddenToLocations < ActiveRecord::Migration[7.1]
  def change
    add_column(:locations, :hidden, :boolean, null: false, default: false)
  end
end
