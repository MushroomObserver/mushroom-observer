class AddEndedToInatImportJobTrackers < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_import_job_trackers, :ended_at, :datetime
  end
end
