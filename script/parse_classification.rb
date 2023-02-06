#!/usr/bin/env ruby
# frozen_string_literal: true

NAME_REGEXP    = /_([^_]*)_/
DOMAIN_REGEXP  = /Domain: #{NAME_REGEXP}/
KINGDOM_REGEXP = /Kingdom: #{NAME_REGEXP}/
PHYLUM_REGEXP  = /Phylum: #{NAME_REGEXP}/
CLASS_REGEXP   = /Class: #{NAME_REGEXP}/
ORDER_REGEXP   = /Order: #{NAME_REGEXP}/
FAMILY_REGEXP  = /Family: #{NAME_REGEXP}/

def parse(str, regexp)
  str.match(regexp)&.[](1)
end

ARGF.each do |line|
  id, str = line.chomp.split("\t")
  puts [
    id,
    parse(str, DOMAIN_REGEXP),
    parse(str, KINGDOM_REGEXP),
    parse(str, PHYLUM_REGEXP),
    parse(str, CLASS_REGEXP),
    parse(str, ORDER_REGEXP),
    parse(str, FAMILY_REGEXP)
  ].join("\t")
end

exit 0
