class RemoveTransactions < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :transactions
    remove_column :comments, :sync_id
    remove_column :images, :sync_id
    remove_column :interests, :sync_id
    remove_column :licenses, :sync_id
    remove_column :location_descriptions, :sync_id
    remove_column :locations, :sync_id
    remove_column :name_descriptions, :sync_id
    remove_column :names, :sync_id
    remove_column :namings, :sync_id
    remove_column :notifications, :sync_id
    remove_column :observations, :sync_id
    remove_column :projects, :sync_id
    remove_column :species_lists, :sync_id
    remove_column :synonyms, :sync_id
    remove_column :user_groups, :sync_id
    remove_column :users, :sync_id
    remove_column :votes, :sync_id
  end

  def self.down
    fail "This migration cannot be reversed!"
  end
end
