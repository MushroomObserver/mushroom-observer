# frozen_string_literal: true

class AddVersionToFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slip_job_trackers, :version, :integer, default: 1)
  end
end
