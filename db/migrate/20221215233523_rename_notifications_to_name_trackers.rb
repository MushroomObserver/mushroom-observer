class RenameNotificationsToNameTrackers < ActiveRecord::Migration[6.1]
  def self.up
    rename_table :notifications, :name_trackers
    NameTracker.find_each do |n_t|
      Interest.create!({
        target_type: "NameTracker",
        target_id: n_t.id,
        user_id: n_t.user_id,
        state: 1,
        updated_at: n_t.updated_at
      })
    end
  end
  def self.down
    rename_table :name_trackers, :notifications
    Interest.where(target_type: "NameTracker").delete_all
  end
end
