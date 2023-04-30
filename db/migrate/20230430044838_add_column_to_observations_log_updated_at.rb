class AddColumnToObservationsLogUpdatedAt < ActiveRecord::Migration[6.1]
  def up
    add_column(:observations, :log_updated_at, :datetime)
    Observation.joins(:rss_log).update_all(log_updated_at: RssLog[:updated_at])
    # cleanup the 24113 observations with no rss_log
    # Observation.where(log_updated_at: nil).
    #             update_all(log_updated_at: Observation[:updated_at])
    # change_column(:observations, :log_updated_at, :datetime, null: false)
  end
  def down
    remove_column(:observations, :log_updated_at)
  end
end
