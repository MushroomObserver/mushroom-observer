class MakeQueryTypeIntoEnum < ActiveRecord::Migration
  def self.up
    SearchState.connection.delete   'DELETE FROM search_states   WHERE id > 0'
    SequenceState.connection.delete 'DELETE FROM sequence_states WHERE id > 0'
    remove_column :search_states,   :query_type
    remove_column :sequence_states, :query_type
    add_column :search_states,   :query_type, :enum, :limit => SearchState.all_query_types
    add_column :sequence_states, :query_type, :enum, :limit => SearchState.all_query_types
  end

  def self.down
  end
end
