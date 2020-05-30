# encoding: utf-8
class RemoveOldTables < ActiveRecord::Migration[4.2]
  def self.up
    for old_table in %w(
      authors_descriptions
      authors_locations
      authors_names
      editors_descriptions
      editors_locations
      editors_names
      descriptions
      draft_names
      past_descriptions
      past_draft_names
      past_locations
      past_names
      search_states
      sequence_states)
      Name.connection.execute("DROP TABLE IF EXISTS #{old_table}")
    end
  end

  def self.down
  end
end
