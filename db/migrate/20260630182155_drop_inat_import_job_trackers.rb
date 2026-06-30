# frozen_string_literal: true

class DropInatImportJobTrackers < ActiveRecord::Migration[7.2]
  def up
    drop_table(:inat_import_job_trackers)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
