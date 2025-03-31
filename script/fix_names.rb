#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensure that name.sort_name is consistent with
# Name.parse(name.search_name).sort_name

NAME_METHODS = %w[
  text_name
  search_name
  display_name
  sort_name
].freeze

def update
  Name.find_each do |name|
    name.skip_notify = true
    parse = Name.parse_name(name.search_name, deprecated: name.deprecated,
                                              rank: name.rank)
    if parse
      sleep(0.5) if check_names(name, parse)
    else
      puts("#{name.id},#{name.search_name},ERROR,#{name.created_at},BAD PARSE")
    end
  end
end

def check_names(name, parse)
  changed = false
  NAME_METHODS.each do |method|
    changed = check_name(method, name, parse) || changed
  end
  changed
end

def check_name(method, name, parse)
  old_value = name.send(method)
  new_value = parse.send(method)
  return false if old_value == new_value

  name.send(:"#{method}=", new_value)
  return true if name.save

  errs = name.errors.map do |err|
    "\"#{err.full_message.strip}\""
  end
  puts("#{name.id},#{method},\"#{old_value}\",\"#{new_value}\"," \
       "#{name.created_at},#{errs.join(",")}")
  true
end

update
