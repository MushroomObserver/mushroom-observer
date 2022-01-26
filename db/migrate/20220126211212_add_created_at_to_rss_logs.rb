class AddCreatedAtToRssLogs < ActiveRecord::Migration[5.2]

  def up
    add_column :rss_logs, :created_at, :datetime
  end

  def down
    remove_column :rss_logs, :created_at
  end

end
