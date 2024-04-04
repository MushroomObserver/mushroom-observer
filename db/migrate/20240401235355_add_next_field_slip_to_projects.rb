# frozen_string_literal: true

class AddNextFieldSlipToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column(:projects, :next_field_slip, :integer, default: 0, null: false)
  end
end
