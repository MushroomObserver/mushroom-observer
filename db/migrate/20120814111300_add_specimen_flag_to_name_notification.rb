# encoding: utf-8

class AddSpecimenFlagToNameNotification < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:notifications, :require_specimen, :boolean, default: false, null: false)
  rescue
    nil
  end

  def self.down
    remove_column :notifications, :require_specimen
  end
end
