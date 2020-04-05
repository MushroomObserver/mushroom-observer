class AddRegistrationNotes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :conference_registrations, :notes, :text
  end

  def self.down
    remove_column :conference_registrations, :notes
  end
end
