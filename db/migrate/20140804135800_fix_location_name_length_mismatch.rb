class FixLocationNameLengthMismatch < ActiveRecord::Migration[4.2]
  def self.up
    change_column(:locations_versions, :name, :string, limit: 1024)
  end

  def self.down
  end
end
