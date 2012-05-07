class AddRegistrationVerified < ActiveRecord::Migration
  def self.up
    add_column :conference_registrations, :verified, :datetime
  end

  def self.down
    remove_column :conference_registrations, :verified
  end
end
