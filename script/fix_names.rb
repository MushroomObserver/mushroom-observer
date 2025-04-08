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

def update(controller)
  last_id = controller.start
  Name.where(id: controller.start..).
    order(id: :asc).limit(controller.count).find_each do |name|
    process_name(name, controller.sleep_time)
    last_id = name.id
  end
  puts("Last ID: #{last_id}")
end

def process_name(name, sleep_time)
  name.skip_notify = true
  parse = Name.parse_name(name.search_name, deprecated: name.deprecated,
                                            rank: name.rank)
  if parse
    check_parse(name, parse, sleep_time)
  else
    puts("#{name.id},#{name.search_name},ERROR,#{name.created_at},BAD PARSE")
  end
end

def check_parse(name, parse, sleep_time)
  return unless check_names(name, parse)

  puts("Updated #{name.id}")
  sleep(sleep_time)
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

class Controller
  attr_accessor :start
  attr_accessor :count
  attr_accessor :sleep_time

  def initialize(args)
    @start = args[0].to_i
    @count = args[1].to_i
    @sleep_time = args[2].to_f
  end
end

controller = Controller.new(ARGV)
update(controller)
