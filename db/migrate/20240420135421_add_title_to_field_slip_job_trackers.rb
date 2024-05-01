# frozen_string_literal: true

class AddTitleToFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slip_job_trackers, :title, :string,
               limit: 100, default: "", null: false)
  end
end
