class MoApiKeys < ActiveRecord::Migration[4.2]
  def self.up
    create_table :mo_api_keys, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column :created, :datetime
      t.column :last_used, :datetime
      t.column :num_uses, :integer, default: 0
      t.column :user_id, :integer, null: false
      t.column :key, :string, limit: 128, null: false
      t.column :notes, :text
    end
  end

  def self.down
    drop_table :mo_api_keys
  end
end
