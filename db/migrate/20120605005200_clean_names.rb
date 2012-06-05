class CleanNames < ActiveRecord::Migration
  def self.up
    change_column(:names, :rank, :enum, :limit => Name.all_ranks)
    change_column(:names, :author, :string, :limit => 100, :null => false)
  end

  def self.down
  end
end

