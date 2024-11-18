# frozen_string_literal: true

class CreateOriginalImageRequestsTable < ActiveRecord::Migration[7.1]
  def change
    create_table(:original_image_requests) do |t|
      t.integer(:user_id)
      t.integer(:image_id)
      t.timestamps
    end
  end
end
