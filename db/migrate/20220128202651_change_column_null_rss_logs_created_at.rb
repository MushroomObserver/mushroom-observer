class ChangeColumnNullRssLogsCreatedAt < ActiveRecord::Migration[5.2]
  def change
    change_column_null(:rss_logs, :created_at, false)
  end
end
