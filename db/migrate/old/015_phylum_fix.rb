class PhylumFix < ActiveRecord::Migration
  # This ensures that the current values for Name.all_ranks are being used.
  def self.up
    add_column :names, :rank_tmp, :enum, :limit => Name.all_ranks
    Name.connection.update("update names set rank_tmp=rank+0")
    remove_column :names, :rank
    add_column :names, :rank, :enum, :limit => Name.all_ranks
    Name.connection.update("update names set rank=rank_tmp")
    remove_column :names, :rank_tmp
  end

  # Down doesn't really make sense in this case
end
