class CreateRssLogs < ActiveRecord::Migration
  def self.up
    create_table :rss_logs, :force => true do |t| # :force => true tells it to drop before create
      t.column "observation_id", :integer # If both observation and species_list are NULL, then
      t.column "species_list_id", :integer # the owning object was deleted
      t.column "modified", :datetime
      t.column "notes", :text # If observation_id and species_list_id are NULL then first line is title
    end
  end

  def self.down
    drop_table :rss_logs
  end
end
