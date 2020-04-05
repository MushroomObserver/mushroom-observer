class ConferenceRegistrationNote < ActiveRecord::Migration[4.2]
  def self.up
    add_column :conference_events, :registration_note, :text
  end

  def self.down
    remove_column :conference_events, :registration_note
  end
end
