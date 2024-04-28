# frozen_string_literal: true

class AddUserToFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slip_job_trackers, :user_id, :integer)
  end
end
