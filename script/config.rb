#!/usr/bin/env ruby
# frozen_string_literal: true

require("yaml")

class ImageConfigData
  def initialize
    @env = ENV.fetch("RAILS_ENV", "development")
    @config = YAML.load_file("#{root}/config/image_config.yml")[@env]
  end

  def root
    File.expand_path("..", __dir__)
  end

  def local_image_files
    # Use MO_IMAGE_ROOT if set (passed from Rails for worker-specific paths)
    ENV["MO_IMAGE_ROOT"] || format(@config["local_image_files"], root: root)
  end

  def image_sources
    # Apply worker-specific path transformations if MO_IMAGE_ROOT is set
    if ENV["MO_IMAGE_ROOT"]
      apply_worker_paths(@config["image_sources"])
    else
      @config["image_sources"]
    end
  end

  def keep_these_image_sizes_local
    @config["keep_these_image_sizes_local"]
  end

  private

  def apply_worker_paths(sources)
    # Deep copy to avoid modifying the original
    result = Marshal.load(Marshal.dump(sources))
    result.each do |_server, specs|
      [:test, :read, :write].each do |key|
        next unless specs[key].is_a?(String)
        next if specs[key] == ":transferred_flag"

        specs[key] = append_worker_suffix(specs[key])
      end
    end
    result
  end

  def append_worker_suffix(path)
    # Extract worker number from MO_IMAGE_ROOT
    # e.g., "/path/to/test_images-8" -> "8"
    return path unless ENV["MO_IMAGE_ROOT"] =~ /-(\d+)$/
    worker_suffix = Regexp.last_match(1)

    # Don't modify URLs or special flags
    return path if path.start_with?("https://", "http://") || path == ":transferred_flag"

    # Handle file:// URLs and regular paths
    if path.start_with?("file://")
      prefix = "file://"
      actual_path = path.sub(%r{^file://}, "")
    else
      prefix = ""
      actual_path = path
    end

    # Append worker suffix to test_images, test_server paths
    modified_path = actual_path.gsub(
      /(test_images|test_server\d+|test_locales)(?=\/|$)/,
      "\\1-#{worker_suffix}"
    )

    "#{prefix}#{modified_path}"
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
  puts(ARGV.map { |arg| eval(arg).to_s }.join("\n"))
  exit(0)
end
