# encoding: utf-8
class ObjectToTarget < ActiveRecord::Migration[4.2]
  def self.up
    # It is unsafe to override the "object_id" method starting in ruby 1.9.
    rename_column(:comments,  :object_id,   :target_id)
    rename_column(:comments,  :object_type, :target_type)
    rename_column(:interests, :object_id,   :target_id)
    rename_column(:interests, :object_type, :target_type)
  end

  def self.down
    rename_column(:comments,  :target_id,   :object_id)
    rename_column(:comments,  :target_type, :object_type)
    rename_column(:interests, :target_id,   :object_id)
    rename_column(:interests, :target_type, :object_type)
  end
end
