class AddColumnToObservationsLogUpdatedAt < ActiveRecord::Migration[6.1]
  def up
    add_column(:observations, :log_updated_at, :datetime)
    Observation.joins(:rss_log).update_all(log_updated_at: RssLog[:updated_at])
  end
  def down
    remove_column(:observations, :log_updated_at)
  end
end
