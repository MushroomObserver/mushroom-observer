# encoding: utf-8
class RemoveEmailDigest < ActiveRecord::Migration
  def self.up
    remove_column :users, :email_digest
  end

  def self.down
    add_column :users, :email_digest, :string
  end
end
