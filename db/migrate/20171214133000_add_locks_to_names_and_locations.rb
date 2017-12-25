class AddLocksToNamesAndLocations < ActiveRecord::Migration
  def up
    add_column :names, :locked, :boolean, default: false, null: false
    add_column :locations, :locked, :boolean, default: false, null: false

    # Lock "Fungi".
    Name.unknown.update_attributes(locked: true)

    # Lock "Earth".
    Location.unknown.update_attributes(locked: true)

    # Lock all the known continents, countries and states.
    location_ids = []
    Location.connection.select_rows(%(
      SELECT id, name FROM locations
    )).each do |id, name|
      word1, word2, the_rest = \
        Location.reverse_name(name).split(",").map(&:strip)
      next unless Location.understood_continents.member?(name) ||
                  Location.understood_countries.member?(name) || (
                    word1 && word2 && the_rest.blank? &&
                    Location.understood_states(word1) &&
                    Location.understood_states(word1).member?(word2)
                  )
      location_ids << id
    end
    Location.connection.execute(%(
      UPDATE locations SET locked = TRUE
      WHERE id IN (#{location_ids.join(",")})
    ))
  end

  def down
    remove_column :names, :locked
    remove_column :locations, :locked
  end
end
