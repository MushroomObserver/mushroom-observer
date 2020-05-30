# encoding: utf-8
class RemoveEmailDigest < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :users, :email_digest
  end

  def self.down
    add_column :users, :email_digest, :string
  end
end
