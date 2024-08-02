# frozen_string_literal: true

class RemoveTmpFieldsFromFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    remove_column(:field_slip_job_trackers, :notes, :text)
    remove_column(:field_slip_job_trackers, :version, :integer)
  end
end
