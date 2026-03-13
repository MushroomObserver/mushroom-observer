# frozen_string_literal: true

# Drop legacy QueuedEmail tables. All email functionality has been migrated
# to ActionMailer + ActiveJob (deliver_later with SolidQueue).
class DropQueuedEmailTables < ActiveRecord::Migration[7.2]
  def up
    # Drop child tables first due to foreign key relationships
    drop_table(:queued_email_integers, if_exists: true)
    drop_table(:queued_email_notes, if_exists: true)
    drop_table(:queued_email_strings, if_exists: true)
    drop_table(:queued_emails, if_exists: true)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration,
          "Cannot restore dropped QueuedEmail tables")
  end
end
