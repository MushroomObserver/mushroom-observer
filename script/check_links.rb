#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("../config/boot")
require_relative("../config/environment")
require_relative("../config/initializers/extensions")

abort(<<HELP) if ARGV.length != 2

  USAGE::

    script/check_links.rb <table> <column>

  DESCRIPTION::

    Loads all the nonempty values in $table.$column and checks any links it
    finds to see if any are broken.

  PARAMETERS::

    --help     Print this message.

HELP

def find_links(val)
  Nokogiri::HTML(val.tpl).css("[href]").map do |node|
    node.attributes["href"]
  end
end

def test_link!(id, link)
  warn("testing: #{link}")
  return if system("curl", "-o/dev/null", "-sfIL", link)

  puts("#{id} #{link}")
end

table = ARGV[0]
column = ARGV[1]

model = table.classify.constantize
model.pluck("id", column).each do |id, val|
  find_links(val).each { |link| test_link!(id, link) } if val.present?
end

exit 0
