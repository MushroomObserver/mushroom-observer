class AddRegistrationCount < ActiveRecord::Migration[4.2]
  def self.up
    add_column :conference_registrations, :how_many, :integer
  end

  def self.down
    remove_column :conference_registrations, :how_many
  end
end
