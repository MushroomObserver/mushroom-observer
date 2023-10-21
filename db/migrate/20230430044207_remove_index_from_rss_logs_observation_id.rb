class RemoveIndexFromRssLogsObservationId < ActiveRecord::Migration[6.1]
  def change
    remove_index :rss_logs, column: [:observation_id]
  end
end
