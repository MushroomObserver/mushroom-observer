class AddRegistrationCount < ActiveRecord::Migration
  def self.up
    add_column :conference_registrations, :how_many, :integer
  end

  def self.down
    remove_column :conference_registrations, :how_many
  end
end
