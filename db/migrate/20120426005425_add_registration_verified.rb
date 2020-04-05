class AddRegistrationVerified < ActiveRecord::Migration[4.2]
  def self.up
    add_column :conference_registrations, :verified, :datetime
  end

  def self.down
    remove_column :conference_registrations, :verified
  end
end
