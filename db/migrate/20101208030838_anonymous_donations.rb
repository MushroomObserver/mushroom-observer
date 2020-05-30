# encoding: utf-8
class AnonymousDonations < ActiveRecord::Migration[4.2]
  def self.up
    add_column :donations, :anonymous, :boolean, default: false, null: false
    add_column :donations, :reviewed, :boolean, default: true, null: false
    add_column :donations, :user_id, :integer
  end

  def self.down
    remove_column :donations, :user_id
    remove_column :donations, :reviewed
    remove_column :donations, :anonymous
  end
end
