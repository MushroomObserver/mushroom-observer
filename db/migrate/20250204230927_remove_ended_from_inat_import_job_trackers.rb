class RemoveEndedFromInatImportJobTrackers < ActiveRecord::Migration[7.2]
  def change
    remove_column :inat_import_job_trackers, :ended, :datetime
  end
end
