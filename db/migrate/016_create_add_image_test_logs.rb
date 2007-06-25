class CreateAddImageTestLogs < ActiveRecord::Migration
  def self.up
    create_table :add_image_test_logs, :force => true do |t| # :force => true tells it to drop before create
      t.column "user_id", :integer # Who ran the test
      t.column "created_at", :datetime # When was the test created by visiting test_add_image
      t.column "upload_start", :datetime # When did the upload start
      t.column "upload_data_start", :datetime # When did actual data transfer start
      t.column "upload_end", :datetime # When did the upload complete
      t.column "image_count", :integer # How many images were uploaded
      t.column "image_bytes", :integer # How many bytes were uploaded
    end
  end

  def self.down
    drop_table :add_image_test_logs
  end
end
