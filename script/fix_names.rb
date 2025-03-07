#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensure that name.sort_name is consistent with Name.parse(name.search_name).sort_name

def update
  Name.find_each do |name|
    name.skip_notify = true
    parse = Name.parse_name(name.search_name, deprecated: name.deprecated, rank: name.rank)
    if parse
      changed = check_name("text_name", name, parse)
      changed = check_name("search_name", name, parse) || changed
      changed = check_name("display_name", name, parse) || changed
      changed = check_name("sort_name", name, parse) || changed
      name.save if changed
    else
      puts("BAD PARSE: #{name.id},#{name.search_name}")
    end
  end
end

def check_name(method, name, parse)
  old_value = name.send(method)
  new_value = parse.send(method)
  return false if old_value == new_value

  name.send("#{method}=", new_value)
  puts("#{name.id},#{method},#{old_value},#{new_value},#{name.created_at}")
  true
end

update
