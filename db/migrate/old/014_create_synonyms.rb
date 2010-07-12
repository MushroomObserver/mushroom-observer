class CreateSynonyms < ActiveRecord::Migration
  def self.up
    create_table "synonyms", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "created", :datetime
      t.column "modified", :datetime
    end
    add_column :names, "synonym_id", :integer
    add_column :names, "deprecated", :boolean, :default => false, :null => false
    add_column :past_names, "deprecated", :boolean, :default => false, :null => false
    add_column :rss_logs, "synonym_id", :integer
  end

  def self.down
    remove_column :rss_logs,  "synonym_id"
    remove_column :past_names, "deprecated"
    remove_column :names, "deprecated"
    remove_column :names, "synonym_id"
    drop_table "synonyms"
  end
end
