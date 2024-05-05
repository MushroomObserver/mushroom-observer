# frozen_string_literal: true

class AddOnePerPageToFieldSlipJobTracker < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slip_job_trackers, :one_per_page, :boolean,
               null: false, default: false)
  end
end
