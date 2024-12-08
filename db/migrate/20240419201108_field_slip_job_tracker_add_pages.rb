# frozen_string_literal: true

class FieldSlipJobTrackerAddPages < ActiveRecord::Migration[7.1]
  def up
    add_column(:field_slip_job_trackers, :pages, :integer,
               default: 0, null: false)
    FieldSlipJobTracker.connection.execute(
      "UPDATE field_slip_job_trackers SET pages = count / 6"
    )
  end

  def down
    remove_column(:field_slip_job_trackers, :pages)
  end
end
