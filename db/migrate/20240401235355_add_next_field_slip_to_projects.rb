# frozen_string_literal: true

class AddNextFieldSlipToProjects < ActiveRecord::Migration[7.1]
  def up
    add_column(:projects, :next_field_slip, :integer, default: 0, null: false)

    # 48 Field Slips were created for the Alpha Test Project
    # before we were tracking the next_field_slip.
    project = Project.find_by(field_slip_prefix: "ATEST")
    return unless project

    project.next_field_slip = 48
    project.save
  end

  def down
    remove_column(:projects, :next_field_slip)
  end
end
