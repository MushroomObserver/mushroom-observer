# frozen_string_literal: true

class ActiveRecord::FixtureSet
  # Reverse lookup of fixture label (how we refer to fixtures) by id.
  def self.reverse_lookup(table, id)
    ActiveRecord::FixtureSet.all_loaded_fixtures[table.to_s].
      fixtures.each_key do |key|
      return key if ActiveRecord::FixtureSet.identify(key) == id
    end
    nil
  end
end
