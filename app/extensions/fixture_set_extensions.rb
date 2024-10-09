# frozen_string_literal: true

class ActiveRecord::FixtureSet
  # Reverse lookup of a fixture's label (e.g. `deprecated_name_obs`) by its id.
  # For better fixture test messages.
  # https://stackoverflow.com/a/32322296/3357635
  def self.reverse_lookup(table, id)
    ActiveRecord::FixtureSet.all_loaded_fixtures[table.to_s].
      fixtures.each_key do |key|
      return key if ActiveRecord::FixtureSet.identify(key) == id
    end
    nil
  end
end
