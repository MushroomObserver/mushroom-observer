class AddIndexToRssLogsObservationId < ActiveRecord::Migration[6.1]
  def change
    add_index :rss_logs, :observation_id
  end
end
