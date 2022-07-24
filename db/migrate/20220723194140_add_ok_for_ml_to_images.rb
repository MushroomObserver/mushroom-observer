# frozen_string_literal: true

class AddOkForMlToImages < ActiveRecord::Migration[6.1]
  def change
    add_column(:images, :ok_for_ml, :boolean, default: true, null: false)
  end
end
