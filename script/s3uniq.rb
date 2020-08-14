#!/usr/bin/env ruby
# frozen_string_literal: true

abort(<<"EOB") if ARGV.any? { |arg| ["-h", "--help"].include?(arg) }

  USAGE::

    cat input_files | script/s3uniq.rb > output_file

  DESCRIPTION::

    Reads key/value pairs from stdout and prints only the last entry
    corresponding to each key.  Input and outout are tab-delimited.

EOB

abort("Unexpected parameters: #{ARGV.inspect}") unless ARGV.empty?

data = {}
$stdin.each_line do |line|
  key, val = line.split("\t", 2)
  data[key] = val
end
data.each do |key, val|
  $stdout.write([key, val].join("\t"))
end

exit(0)
