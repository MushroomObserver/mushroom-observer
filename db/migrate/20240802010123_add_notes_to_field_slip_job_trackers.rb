# frozen_string_literal: true

class AddNotesToFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slip_job_trackers, :notes, :text)
  end
end
