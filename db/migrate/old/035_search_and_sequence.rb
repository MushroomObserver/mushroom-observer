class SearchAndSequence < ActiveRecord::Migration
  def self.up
    create_table "search_states", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "timestamp",    :datetime
      t.column "access_count", :integer
      t.column "query_type",   :string, :limit => 20
      t.column "title",        :string, :limit => 100
      t.column "conditions",   :text
      t.column "order",        :text
      t.column "source",       :string, :limit => 20
    end

    create_table "sequence_states", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "timestamp",     :datetime
      t.column "access_count",  :integer
      t.column "query_type",    :string, :limit => 20
      t.column "query",         :text
      t.column "current_id",    :integer
      t.column "current_index", :integer
      t.column "prev_id",       :integer
      t.column "next_id",       :integer
    end
  end

  def self.down
    drop_table :search_states
    drop_table :sequence_states
  end
end
