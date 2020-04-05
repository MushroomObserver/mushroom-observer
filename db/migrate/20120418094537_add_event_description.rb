class AddEventDescription < ActiveRecord::Migration[4.2]
  def self.up
    add_column :conference_events, :description, :text
  end

  def self.down
    remove_column :conference_events, :description
  end
end
