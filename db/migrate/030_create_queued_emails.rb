class CreateQueuedEmails < ActiveRecord::Migration
  def self.up
    create_table :queued_emails do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :to_user_id, :integer, :default => 0, :null => false
      t.column :flavor, :enum, :limit => QueuedEmail.all_flavors
      t.column :queued, :datetime
    end
    
    create_table :queued_email_integers do |t|
      t.column :queued_email_id, :integer, :default => 0, :null => false
      t.column :key, :string, :limit => 100
      t.column :value, :integer, :default => 0, :null => false
    end
    
    create_table :queued_email_strings do |t|
      t.column :queued_email_id, :integer, :default => 0, :null => false
      t.column :key, :string, :limit => 100
      t.column :value, :string, :limit => 100
    end
    
    create_table :queued_email_notes do |t|
      t.column :queued_email_id, :integer, :default => 0, :null => false
      t.column :value, :text
    end
  end

  def self.down
    drop_table :queued_emails
    drop_table :queued_email_integers
    drop_table :queued_email_strings
    drop_table :queued_email_notes
  end
end
