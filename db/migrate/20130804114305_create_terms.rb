class CreateTerms < ActiveRecord::Migration[4.2]
  def self.up
    create_table :terms do |t|
      t.string "name", limit: 1024
      t.text "description"
      t.integer "image_id"
      t.timestamps
    end
  end

  def self.down
    drop_table :terms
  end
end
