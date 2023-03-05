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
HELP_ARGS = ["-h", "--help"].freeze

app_root = File.expand_path("..", __dir__)
require("#{app_root}/config/consts.rb")
require("#{app_root}/app/classes/ip_stats.rb")
require("fileutils")
require("time")

abort(<<HELP) if ARGV.any? { |arg| HELP_ARGS.include?(arg) }

  USAGE::

    script/update_ip_stats.rb [<ips>...]

  DESCRIPTION::

    Updates config/blocked_ips.txt based on latest info in log/ip_stats.txt.
    Cleans out everything more than one hour old in log/ip_stats.txt.

  PARAMETERS::

    --help     Print this message.
    <ip>       Report the stats for this IP address.

HELP

def bad_ip?(stats)
  if stats[:user].to_s != "" || stats[:api_key].to_s != ""
    report_user(stats) if stats[:rate] * 60  >= 30 || # requests per minute
                          stats[:load] * 100 >= 100   # pct use of one worker
  elsif stats[:rate] * 60  > 20 || # requests per minute
        stats[:load] * 100 > 50    # pct use of one worker
    report_nonuser(stats) unless ignore_ip?(stats[:ip])
    return true
  end
  false
end

def ignore_ip?(ip)
  IpStats.blocked?(ip) || IpStats.okay?(ip)
end

def report_user(stats)
  id = stats[:user]
  puts("User ##{id} is hogging the server!")
  puts("  API key: #{stats[:api_key]}") if stats[:api_key].to_s != ""
  puts("  https://mushroomobserver.org/users/#{id}")
  puts("  request rate: #{(stats[:rate] * 60).round(2)} requests / minute")
  puts("  request rate: 1 every #{(1.0 / stats[:rate]).round(2)} seconds")
  puts("  server load:  #{(stats[:load] * 100).round(2)}% of one worker")
  puts
  system("grep ,#{stats[:ip]}, #{MO.ip_stats_file}")
end

def report_nonuser(stats)
  puts("IP #{stats[:ip]} is hogging the server!")
  puts("  request rate: #{(stats[:rate] * 60).round(2)} requests / minute")
  puts("  request rate: 1 every #{(1.0 / stats[:rate]).round(2)} seconds")
  puts("  server load:  #{(stats[:load] * 100).round(2)}% of one worker")
  puts
  system("grep ,#{stats[:ip]}, #{MO.ip_stats_file}")
end

def clean_and_update_ip_stats_file
  IpStats.clean_stats
  data = IpStats.read_stats
  bad_ips = data.keys.select { |ip| bad_ip?(data[ip]) }
  # Removing then re-adding has effect of updating time stamp on each bad IP.
  IpStats.remove_blocked_ips(bad_ips)
  IpStats.add_blocked_ips(bad_ips)
  # IpStats.clean_blocked_ips # remove old blocked ips after a day
end

def show_one_stat(stats)
  puts(format("%-15s %8.4f %8.4f %8d  %s", stats[:ip], stats[:rate],
              stats[:load], stats[:user], stats[:api_key]))
end

def show_ip_stats(ips)
  data = IpStats.read_stats
  puts("ip              rate/sec   load %     user  api_key")
  ips.each do |ip|
    if data[ip]
      show_one_stat(data[ip])
    else
      puts(format("%-15s no activity", ip))
    end
  end
end

if ARGV.empty?
  clean_and_update_ip_stats_file
else
  show_ip_stats(ARGV)
end

exit(0)
