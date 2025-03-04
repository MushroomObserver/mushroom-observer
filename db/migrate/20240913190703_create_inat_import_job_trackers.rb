class CreateInatImportJobTrackers < ActiveRecord::Migration[7.1]
  def change
    create_table :inat_import_job_trackers do |t|
      t.integer :inat_import_id

      t.timestamps
    end
  end
end
