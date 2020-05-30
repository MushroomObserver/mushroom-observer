# encoding: utf-8
class HouseCleaning < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :add_image_test_logs
    drop_table :t1
    drop_table :t2
  end

  def self.down
    create_table "t2", id: false, force: true do |t|
      t.integer "j"
      t.integer "k"
    end

    create_table "t1", id: false, force: true do |t|
      t.integer "i"
      t.integer "j"
    end

    create_table "add_image_test_logs", force: true do |t|
      t.integer "user_id" # Who ran the test
      t.datetime "created_at" # When was the test created by visiting test_add_image
      t.datetime "upload_start" # When did the upload start
      t.datetime "upload_data_start" # When did actual data transfer start
      t.datetime "upload_end" # When did the upload complete
      t.integer "image_count" # How many images were uploaded
      t.integer "image_bytes" # How many bytes were uploaded
    end
  end
end
