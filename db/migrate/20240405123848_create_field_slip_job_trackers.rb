# frozen_string_literal: true

class CreateFieldSlipJobTrackers < ActiveRecord::Migration[7.1]
  def change
    create_table(:field_slip_job_trackers) do |t|
      t.integer(:start)
      t.integer(:count)
      t.string(:prefix)
      t.integer(:status)

      t.timestamps
    end
  end
end
