# frozen_string_literal: true

class AddOpenMembershipToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column(:projects, :open_membership, :boolean, default: false, null: false)
  end
end
