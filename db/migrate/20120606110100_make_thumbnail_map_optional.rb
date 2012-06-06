# encoding: utf-8

class MakeThumbnailMapOptional < ActiveRecord::Migration
  def self.up
    add_column :users, :thumbnail_maps, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :users, :thumbnail_maps
  end
end

