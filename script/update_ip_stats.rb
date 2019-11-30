#!/usr/bin/env ruby

app_root = File.expand_path("..", __dir__)
require "#{app_root}/app/classes/ip_stats.rb"
require "fileutils"

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
  if stats[:user].present?
    report_user(stats) if stats[:rate] > 1.0 ||
                          stats[:load] > 0.5
  else
    return true if stats[:rate] > 1.0  # one request per second
    return true if stats[:load] > 0.5  # half of one server instance's time
  end
  false
end

def report_user(stats)
  id = stats[:user]
  puts "User ##{id} is hogging the server!"
  puts "  https://mushroomobserver.org/observer/show_user/#{id}"
  puts "  requests rate: #{stats[:rate]} requests/second"
  puts "  server load: #{stats[:load]}% of one server instance"
  puts
end

IpStats.clean_stats
data = IpStats.read_stats
bad_ips = data.keys.select { |ip| bad_ip?(data[ip]) }
IpStats.remove_blocked_ips(bad_ips)
IpStats.add_blocked_ips(bad_ips)

exit 0
