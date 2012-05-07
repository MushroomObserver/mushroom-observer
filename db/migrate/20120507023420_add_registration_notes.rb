class AddRegistrationNotes < ActiveRecord::Migration
  def self.up
    add_column :conference_registrations, :notes, :text
  end

  def self.down
    remove_column :conference_registrations, :notes
  end
end
