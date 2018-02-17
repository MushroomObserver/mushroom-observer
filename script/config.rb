#!/usr/bin/env ruby
#
#  USAGE::
#
#    script/config.rb MO.local_image_files   # arbitrary constant
#    script/config.rb image_servers          # special case
#
#  DESCRIPTION::
#
#  Give shell scripts access to rails app configuration.  Prints value of given
#  constant.  The special "image_servers" prints out a list of image servers
#  all with url and subdirs:
#
#    # production
#    cdmr;cdmr@images.digitalmycology.com:images.digitalmycology.com;
#
#    # test
#    remote1;/home/jason/mo/mo/public/test_server1;
#    remote2;ssh://vagrant@localhost:/home/jason/mo/mo/public/test_server2;thumb,320
#
################################################################################

class Configuration
  def initialize
    @hash = {}
  end

  def method_missing(var, *vals)
    if /^(.*)=$/.match?(var.to_s)
      @hash[var.to_s.sub(/=$/, "")] = vals.first
    else
      @hash[var.to_s]
    end
  end
end

module MushroomObserver
  class Application
    def self.config
      @@config ||= Configuration.new
    end

    def self.configure(&block)
      class_eval(&block)
    end
  end
end

MO = MushroomObserver::Application.config

MO.action_controller = Configuration.new
MO.action_dispatch   = Configuration.new
MO.action_mailer     = Configuration.new
MO.active_support    = Configuration.new
MO.active_record     = Configuration.new
MO.assets            = Configuration.new
MO.i18n              = Configuration.new
MO.web_console       = Configuration.new

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

env = ENV["RAILS_ENV"]
env = "development" if env.to_s == ""
[
  "consts.rb",
  "environments/#{env}.rb",
  # "consts-site.rb" automatically included by env.rb
].each do |file|
  file = File.expand_path("../../config/#{file}", __FILE__)
  require file if File.exist?(file)
end

# If run from command line, evaluate arguments and print results.
if File.basename($PROGRAM_NAME) == "config.rb"
  puts ARGV.map { |arg| eval(arg).to_s }.join("\n")
  exit 0
end
