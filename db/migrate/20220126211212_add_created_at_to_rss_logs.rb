class AddCreatedAtToRssLogs < ActiveRecord::Migration[5.2]
  def change
    add_column(:rss_logs, :created_at, :datetime)
  end
end
