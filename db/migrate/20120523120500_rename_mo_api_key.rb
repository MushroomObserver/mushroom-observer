class RenameMoApiKey < ActiveRecord::Migration
  def self.up
    rename_table :mo_api_keys, :api_keys
  end

  def self.down
    rename_table :api_keys, :mo_api_keys
  end
end
