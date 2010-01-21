class CreateRssEvents < ActiveRecord::Migration
  def self.up
    create_table :rss_events, :force => true do |t| # :force => true tells it to drop before create
      t.column "title", :string, :limit => 100
      t.column "who", :string, :limit => 80 # Left as a string since users may come and go
      t.column "date", :datetime
      t.column "url", :string, :limit => 100
    end
  end

  def self.down
    drop_table :rss_events
  end
end
