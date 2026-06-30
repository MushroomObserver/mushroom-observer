# frozen_string_literal: true

class DropInatImportJobTrackers < ActiveRecord::Migration[7.2]
  def up
    drop_table(:inat_import_job_trackers)
  end

  def down
    create_table(:inat_import_job_trackers,
                 charset: "utf8mb4",
                 collation: "utf8mb4_0900_ai_ci") do |t|
      t.integer("inat_import")
      t.timestamps
    end
  end
end
