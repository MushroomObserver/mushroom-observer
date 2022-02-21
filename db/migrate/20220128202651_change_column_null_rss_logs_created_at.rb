class ChangeColumnNullRssLogsCreatedAt < ActiveRecord::Migration[5.2]
  def change
    change_column_null(:rss_logs, :created_at, false, Time.now)
    RssLog.update_all("created_at = updated_at")
  end
end
