class CreateConferenceTables < ActiveRecord::Migration[4.2]
  def self.up
    create_table :conference_events, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "name", :string, limit: 1024
      t.column "location", :string, limit: 1024
      t.column "start", :date
      t.column "end", :date
      t.timestamps
    end

    create_table :conference_registrations, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "conference_event_id", :integer
      t.column "name", :string, limit: 1024
      t.column "email", :string, limit: 1024
      t.timestamps
    end
  end

  def self.down
    drop_table :conference_registrations
    drop_table :conference_events
  end
end
