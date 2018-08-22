#!/usr/bin/env ruby

require 'yaml'

class ImageConfigData
  def initialize
    @env = ENV["RAILS_ENV"] || "development"
    @config = YAML.load_file("config/image_config.yml")[@env]
  end

  def root
    File.expand_path("../..", __FILE__)
  end

  def local_image_files
    @config["local_image_files"] % {root: root}
  end

  def image_sources
    @config["image_sources"]
  end

  def keep_these_image_sizes_local
    @config["keep_these_image_sizes_local"]
  end
end

MO = ImageConfigData.new

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
      url = specs[:write] % {root: MO.root}
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
