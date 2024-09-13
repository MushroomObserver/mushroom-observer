class RenameInatImportIdToInatImportInInatImportJobTrackers < ActiveRecord::Migration[7.1]
  def change
    rename_column :inat_import_job_trackers, :inat_import_id, :inat_import
  end
end
