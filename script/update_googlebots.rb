#!/usr/bin/env ruby
# frozen_string_literal: true

# Kludge to allow us to include consts.rb without loading entire Rails app.

class Configuration
  def method_missing(method, *args)
    @data ||= {}
    if method.to_s.end_with?("=")
      @data[method.to_s.chop.to_sym] = args[0]
    else
      @data[method]
    end
  end
end

MO = Configuration.new

def config
  MO
end

module MushroomObserver
  class Application
    def self.configure
      yield if block_given?
    end
  end
end

# ----------------------------------------

app_root = File.expand_path("..", __dir__)
require("#{app_root}/config/consts.rb")
require("#{app_root}/app/classes/ip_stats.rb")
require("fileutils")
require("time")

abort(<<"HELP") if ARGV.any? { |arg| ["-h", "--help"].include?(arg) }

  USAGE::

    script/update_googlebots.rb

  DESCRIPTION::

    Updates config/okay_ips.txt to include any new googlebots from latest logs.

  PARAMETERS::

    --help     Print this message.

HELP

def check_file(file)
  ips = {}
  File.open(file).readlines.each do |line|
    match = line.match(/^W.*TIME:.*\srobot\s(\d+\.\d+\.\d+\.\d+).*Googlebot/)
    ips[match[1]] = 1 if match
  end
  ips.keys
end

def verify_ips(ips)
  ips.select do |ip|
    ip.start_with?("66.249.") || verify_ip(ip)
  end
end

def verify_ip(ip)
  match1 = `host #{ip}`.match(/pointer (\S+\.googlebot\.com)\.$/)
  match2 = `host #{match1[1]}`.match(/address (\d+\.\d+\.\d+\.\d+)$/) if match1
  return true if match2 && match2[1] == ip

  ptr1 = match1 ? match1[1] : "nothing"
  ptr2 = match2 ? match2[1] : "nothing"
  warn("False googlebot: #{ip} -> #{ptr1} -> #{ptr2}")
  false
end

old_ips = IpStats.read_okay_ips
new_ips = []
Dir.glob("#{app_root}/log/production.log*").each do |file|
  new_ips += check_file(file) - old_ips - new_ips
end
new_ips = verify_ips(new_ips)
new_ips.each do |ip|
  warn("Adding googlebot ip: #{ip}")
end
IpStats.add_okay_ips(new_ips)

exit(0)
