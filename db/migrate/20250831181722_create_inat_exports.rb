class CreateInatExports < ActiveRecord::Migration[7.2]
  def change
    create_table :inat_exports do |t|
      t.timestamps
      t.integer "user_id"
      t.integer "state", default: 0
      t.string "mo_ids"
      t.string "token"
      t.string "inat_username"
      t.boolean "export_all"
      t.integer "exportables"
      t.integer "exported_count"
      t.datetime "ended_at"
      t.integer "total_exported_count"
      t.integer "total_seconds"
      t.float "avg_export_time"
      t.datetime "last_obs_start"
      t.boolean "cancel"
      t.text "response_errors"
    end
  end
end
