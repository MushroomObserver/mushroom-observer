#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path("config/boot.rb", __dir__))
require(File.expand_path("config/environment.rb", __dir__))

time = Time.now
query = "SELECT MIN(CONCAT(n.deprecated, ',', n.text_name, ',', n.id, ',', n.rank)) FROM names n WHERE id IN (SELECT name_id FROM observations) GROUP BY IF(synonym_id, synonym_id, -id);"
results = Name.connection.select_rows(query).map do |row|
  columns = row[0].split(",")
  { deprecated: columns[0], text_name: columns[1], id: columns[2], rank: columns[3] }
end
puts Time.now-time
