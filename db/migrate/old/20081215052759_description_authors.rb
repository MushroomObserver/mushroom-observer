class DescriptionAuthors < ActiveRecord::Migration
  def self.up
    create_table "authors_names", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.column "name_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
    end

    create_table "editors_names", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.column "name_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
    end
  end

  def self.down
    drop_table "authors_names"
    drop_table "editors_names"
  end
end
