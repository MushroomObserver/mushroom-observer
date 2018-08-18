#!/usr/bin/env rails

def image_servers
  map = {
    thumbnail: "thumb",
    small:     "320",
    medium:    "640",
    large:     "960",
    huge:      "1280",
    full_size: "orig"
  }
  results = []
  MO.image_sources.each do |server, specs|
    if specs[:write]
      url = specs[:write]
      sizes = specs[:sizes] || map.keys
      subdirs = sizes.map { |s| map[s] }.join(",")
      results << [server.to_s, url, subdirs].join(";")
    end
  end
  results.join("\n")
end

# If run from command line, evaluate arguments and print results.
if File.basename($PROGRAM_NAME) == "config.rb"
  puts ARGV.map { |arg| eval(arg).to_s }.join("\n")
  exit 0
end
