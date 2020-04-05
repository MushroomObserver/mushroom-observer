class RemoveConferences < ActiveRecord::Migration[4.2]
  def up
    drop_table :conference_registrations
    drop_table :conference_events
  end

  def down
    create_table :conference_events,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8",
                 force: true do |t|
      t.column "name", :string, limit: 1024
      t.column "location", :string, limit: 1024
      t.column "start", :date
      t.column "end", :date
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "description", :text, limit: 65535
      t.column "registration_note", :text, limit: 65535
    end

    create_table :conference_registrations,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8",
                 force: true do |t|
      t.column "conference_event_id", :integer
      t.column "name", :string, limit: 1024
      t.column "email", :string, limit: 1024
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "how_many", :integer
      t.column "verified", :datetime
      t.column "notes", :text
    end
  end
end
