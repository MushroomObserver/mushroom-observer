#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

class ImageConfigData
  def initialize
    @env = ENV["RAILS_ENV"] || "development"
    @config = YAML.load_file("#{root}/config/image_config.yml")[@env]
  end

  def root
    File.expand_path("..", __dir__)
  end

  def local_image_files
    format(@config["local_image_files"], root: root)
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
    small: "320",
    medium: "640",
    large: "960",
    huge: "1280",
    full_size: "orig"
  }
  results = []
  MO.image_sources.each do |server, specs|
    next unless specs[:write]

    url = format(specs[:write], root: MO.root)
    sizes = specs[:sizes] || map.keys
    subdirs = sizes.map { |s| map[s] }.join(",")
    results << [server.to_s, url, subdirs].join(";")
  end
  results.join("\n")
end

# If run from command line, evaluate arguments and print results.
if File.basename($PROGRAM_NAME) == "config.rb"
  puts ARGV.map { |arg| eval(arg).to_s }.join("\n")
  exit 0
end
