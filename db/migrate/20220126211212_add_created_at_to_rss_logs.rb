class AddCreatedAtToRssLogs < ActiveRecord::Migration[5.2]

  def up
    add_column :rss_logs, :created_at, :datetime
    change_column_null :rss_logs, :created_at, false
  end

  def down
    remove_column :rss_logs, :created_at
  end

end
