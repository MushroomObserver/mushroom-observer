# frozen_string_literal: true

class AddApprovedToNameTrackers < ActiveRecord::Migration[6.1]
  def up
    rename_column(:name_trackers, :obj_id, :name_id)
    add_column(:name_trackers, :approved, :boolean, default: true, null: false)
    NameTracker.where(note_template: "").update_all(note_template: nil)
    NameTracker.where.not(note_template: nil).update_all(approved: true)
  end

  def down
    remove_column(:name_trackers, :approved)
    rename_column(:name_trackers, :name_id, :obj_id)
  end
end
