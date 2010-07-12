class PastPhylumFix < ActiveRecord::Migration
  def self.up
    add_column :past_names, :rank_tmp, :enum, :limit => Name.all_ranks
    Name.connection.update("update past_names set rank_tmp=rank+0")
    remove_column :past_names, :rank
    add_column :past_names, :rank, :enum, :limit => Name.all_ranks
    Name.connection.update("update past_names set rank=rank_tmp")
    remove_column :past_names, :rank_tmp
  end
end
