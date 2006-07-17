class AddSpeciesLists < ActiveRecord::Migration
  def self.up
    create_table "species_lists", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "created", :datetime
      t.column "modified", :datetime
      t.column "when", :date
      t.column "user_id", :integer
      t.column "where", :string, :limit => 100
      t.column "title", :string, :limit => 100
      t.column "notes", :text
    end
    
    create_table "observations_species_lists", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.column "observation_id", :integer, :default => 0, :null => false
      t.column "species_list_id", :integer, :default => 0, :null => false
    end
  end

  def self.down
    drop_table "species_lists"
    drop_table "observations_species_lists"
  end
end
