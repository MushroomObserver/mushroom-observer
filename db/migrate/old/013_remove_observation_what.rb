class RemoveObservationWhat < ActiveRecord::Migration
  def self.up
    remove_column :observations,  "what"
  end

  def self.down
    add_column :observations,  "what", :string, :limit => 100
    obs = Observation.find :all
    for o in obs
      o.what = o.name.text_name
      o.save
    end
  end
end
