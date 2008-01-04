class CreateLocations < ActiveRecord::Migration
  
  def self.update_observations_by_where(location, where)
    if where
      observations = Observation.find_all_by_where(where)
      for o in observations
        unless o.location_id
          o.location = location
          o.where = nil
          o.save
        end
      end
    end
  end
  
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
    
    now = Time.now
    for loc_attrs in [{
        :display_name => "Albion, Mendocino Co., California, USA",
        :north => 39.32,
        :west => -123.82,
        :east => -123.74,
        :south => 39.21,
        :high => 100.0,
        :low => 0.0
      }, {
        :display_name => "Burbank, Los Angeles Co., California, USA",
        :north => 34.22,
        :west => -118.37,
        :east => -118.29,
        :south => 34.15,
        :high => 294.0,
        :low => 148.0
      }, {
        :display_name => "\"Mitrula Marsh\", Sand Lake, Bassetts, Yuba Co., California, USA",
        :north => 39.7184,
        :west => -120.687,
        :east => -120.487,
        :south => 39.5184
      }, {
        :display_name => "Salt Point State Park, Sonoma Co., California, USA",
        :north => 38.5923,
        :west => -123.343,
        :east => -123.283,
        :south => 38.5584,
        :high => 100.0,
        :low => 0.0
      }, {
        :display_name => "Gualala, Mendocino Co., California, USA",
        :north => 38.7868,
        :west => -123.557,
        :east => -123.519,
        :south => 38.7597,
        :high => 100.0,
        :low => 0.0
      }, {
        :display_name => "Elgin County, Ontario, Canada",
        :north => 42.876,
        :west => -81.8179,
        :east => -80.8044,
        :south => 42.4701,
      }, {
        :display_name => 'Brett Woods, Fairfield Co., Connecticut, USA',
        :north => 41.2125,
        :west => -73.3295,
        :east => -73.3215,
        :south => 41.1939
      }, {
        :display_name => 'Point Reyes National Seashore, Marin Co., California, USA',
        :north => 38.2441,
        :west => -123.0256,
        :east => -122.7092,
        :south => 37.9255
      }, {
        :display_name => 'Howarth Park, Santa Rosa, Sonoma Co., California, USA',
        :north => 38.4582,
        :west => -122.6712,
        :east => -122.6632,
        :south => 38.4496
      }]
      loc = Location.new(loc_attrs)
      loc.user_id = 1
      loc.created = now
      loc.modified = now
      if loc.save
        print "Created #{loc.display_name}\n"
        update_observations_by_where(loc, loc.display_name)
      else
        print "Unable to create #{loc_attrs.display_name}\n"
      end
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
