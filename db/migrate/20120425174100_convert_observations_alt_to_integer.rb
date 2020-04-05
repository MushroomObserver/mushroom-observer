class ConvertObservationsAltToInteger < ActiveRecord::Migration[4.2]
  def self.up
    # Not used yet in production, so no harm in just deleting and reinserting.
    remove_column :observations, :alt
    add_column :observations, :alt, :integer
  end

  def self.down
  end
end
