#!/usr/bin/env ruby

# Kludge to allow us to include consts.rb without loading entire Rails app.

class Configuration
  def method_missing(method, *args)
    @data ||= {}
    if method.to_s.match?(/=$/)
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
require "#{app_root}/config/consts.rb"
require "#{app_root}/app/classes/ip_stats.rb"
require "fileutils"
require "time"

abort(<<"HELP") if ARGV.any? { |arg| ["-h", "--help"].include?(arg) }

  USAGE::

    script/update_ip_stats.rb

  DESCRIPTION::

    Updates config/blocked_ips.txt based on latest info in log/ip_stats.txt.
    Cleans out everything more than one hour old in log/ip_stats.txt.

  PARAMETERS::

    --help     Print this message.

HELP

def bad_ip?(stats)
  if stats[:user].to_s != ""
    report_user(stats) if stats[:rate] * 60  >= 30 || # requests per minute
                          stats[:load] * 100 >= 100   # pct use of one worker
  elsif stats[:rate] * 60  > 20 || # requests per minute
        stats[:load] * 100 > 50    # pct use of one worker
    report_nonuser(stats) unless IpStats.blocked?(stats[:ip])
    return true
  end
  false
end

def report_user(stats)
  id = stats[:user]
  puts "User ##{id} is hogging the server!"
  puts "  https://mushroomobserver.org/observer/show_user/#{id}"
  puts "  request rate: #{(stats[:rate] * 60).round(2)} requests / minute"
  puts "  request rate: 1 every #{(1.0 / stats[:rate]).round(2)} seconds"
  puts "  server load:  #{(stats[:load] * 100).round(2)}% of one worker"
  puts
end

def report_nonuser(stats)
  puts "IP #{stats[:ip]} is hogging the server!"
  puts "  request rate: #{(stats[:rate] * 60).round(2)} requests / minute"
  puts "  request rate: 1 every #{(1.0 / stats[:rate]).round(2)} seconds"
  puts "  server load:  #{(stats[:load] * 100).round(2)}% of one worker"
  puts
end

IpStats.clean_stats
data = IpStats.read_stats
bad_ips = data.keys.select { |ip| bad_ip?(data[ip]) }
# Removing then re-adding has effect of updating the time stamp on each bad IP.
IpStats.remove_blocked_ips(bad_ips)
IpStats.add_blocked_ips(bad_ips)

exit 0
