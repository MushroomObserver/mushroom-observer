# frozen_string_literal: true

class AddImageToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column(:projects, :image_id, :integer)
  end
end
