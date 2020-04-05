# encoding: utf-8

class AddScientificNameToLocations < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:locations, :scientific_name, :string, limit: 1024)
    add_column(:locations_versions, :scientific_name, :string, limit: 1024)
    fill_in_scientific_names("locations")
    fill_in_scientific_names("locations_versions")
  end

  def self.down
    remove_column(:locations, :scientific_name)
    remove_column(:locations_versions, :scientific_name)
  end

  def self.fill_in_scientific_names(table)
    data = []
    for id, name in Location.connection.select_rows %(
      SELECT id, name FROM #{table}
    )
      data[id.to_i - 1] = Location.reverse_name(name)
    end
    vals = data.map { |v| Location.connection.quote(v.to_s) }.join(",")
    Name.connection.update %(
      UPDATE #{table} SET scientific_name = ELT(id, #{vals})
    )
  end
end
