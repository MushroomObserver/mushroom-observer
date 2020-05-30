class CreatePublications < ActiveRecord::Migration[4.2]
  def self.up
    create_table :publications, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer :user_id
      t.text :full
      t.string :link
      t.text :how_helped
      t.boolean :mo_mentioned
      t.boolean :peer_reviewed

      t.timestamps
    end
  end

  def self.down
    drop_table :publications
  end
end
