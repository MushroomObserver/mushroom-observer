class CreateLocations < ActiveRecord::Migration
  def self.up
    create_table :locations do |t|
      t.column :created, :datetime
      t.column :modified, :datetime
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :version, :integer, :default => 0, :null => false
      t.column :display_name, :string, :limit => 200
      t.column :notes, :text

      t.column :north, :float # Interface enforces that north >= south
      t.column :south, :float
      t.column :west, :float # Area is assumed to be between west and east
      t.column :east, :float # including any rollover
      t.column :high, :float # Stored in meters, but interface should allow for ft
      t.column :low, :float # Interface should enforce that high >= low
    end
    add_column :observations, "location_id", :integer
    add_column :observations, "is_collection_location", :boolean, :default => true, :null => false

    create_table :past_locations, :force => true do |t|
      t.column :location_id, :integer
      t.column :created, :datetime
      t.column :modified, :datetime
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :version, :integer, :default => 0, :null => false
      t.column :display_name, :string, :limit => 200
      t.column :notes, :text

      t.column :north, :float # Interface enforces that north >= south
      t.column :south, :float
      t.column :west, :float # Area is assumed to be between west and east
      t.column :east, :float # including any rollover
      t.column :high, :float # Stored in meters, but interface should allow for ft
      t.column :low, :float # Interface should enforce that high >= low
    end
  end

  def self.down
    for o in Observation.find(:all, :conditions => "`where` is NULL")
      o.where = o.place_name
      o.save
    end
    
    drop_table :past_locations
    remove_column :observations, "location_id"
    remove_column :observations, "is_collection_location"
    drop_table :locations
  end
end
