# encoding: utf-8
class ExpandLocationNames < ActiveRecord::Migration[4.2]
  def self.up
    add_column :observations, :where_tmp, :string, limit: 1024
    Name.connection.update("update observations set where_tmp=`where`")
    remove_column :observations, :where
    add_column :observations, :where, :string, limit: 1024
    Name.connection.update("update observations set `where`=where_tmp")
    remove_column :observations, :where_tmp

    add_column :locations, :name_tmp, :string, limit: 1024
    Name.connection.update("update locations set name_tmp=name")
    remove_column :locations, :name
    add_column :locations, :name, :string, limit: 1024
    Name.connection.update("update locations set name=name_tmp")
    remove_column :locations, :name_tmp
  end

  def self.down
    add_column :observations, :where_tmp, :string, limit: 100
    Name.connection.update("update observations set where_tmp=`where`") # May cause truncation
    remove_column :observations, :where
    add_column :observations, :where, :string, limit: 100
    Name.connection.update("update observations set `where`=where_tmp")
    remove_column :observations, :where_tmp

    add_column :locations, :name_tmp, :string, limit: 200
    Name.connection.update("update locations set name_tmp=name") # May cause truncation
    remove_column :locations, :name
    add_column :locations, :name, :string, limit: 200
    Name.connection.update("update locations set name=name_tmp")
    remove_column :locations, :name_tmp
  end
end
