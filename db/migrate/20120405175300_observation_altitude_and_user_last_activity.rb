class ObservationAltitudeAndUserLastActivity < ActiveRecord::Migration
  def self.up
    add_column :observations, :alt, :float
    add_column :users, :last_activity, :datetime
  end

  def self.down
    remove_column :observations, :alt
    remove_column :users, :last_activity
  end
end
