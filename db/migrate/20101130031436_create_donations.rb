# encoding: utf-8
class CreateDonations < ActiveRecord::Migration[4.2]
  def self.up
    create_table :donations, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "amount", :decimal, precision: 12, scale: 2
      t.column "who", :string, limit: 100
      t.column "email", :string, limit: 100
      t.timestamps
    end
  end

  def self.down
    drop_table :donations
  end
end
