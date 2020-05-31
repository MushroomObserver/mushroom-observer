# frozen_string_literal: true

require "test_helper"
require "fileutils"

class IpStatsTest < UnitTestCase
  def setup
    fixture_path = "#{::Rails.root}/test/fixtures"
    setup_file(MO.blocked_ips_file, "#{fixture_path}/blocked_ips.txt")
    setup_file(MO.okay_ips_file, "#{fixture_path}/okay_ips.txt")
  end

  # Might want to explicitly delete blocked_ips.txt and okay_ip.txt
  # in case tests in other modules are sensitive to them.  This module
  # could leave them in a random state.

  def setup_file(dest_file, src_file)
    return if File.exist?(dest_file) &&
              File.size(dest_file) == File.size(src_file) &&
              (File.mtime(dest_file) - File.mtime(src_file)).abs < 1e-3

    File.open(dest_file, "w") do |fh|
      fh.write(File.open(src_file, "r").read)
    end
    FileUtils.touch(dest_file, mtime: File.mtime(src_file))
    IpStats.reset!
  end

  def test_blocked_ips
    new_ip = "87.65.43.21"
    assert_true(IpStats.blocked?("12.34.56.78")) # in blocked_ips.txt
    assert_false(IpStats.blocked?("3.14.15.9"))  # in okay_ips.txt
    assert_false(IpStats.blocked?(new_ip))       # not in either yet
    File.open(MO.blocked_ips_file, "a") do |fh|
      fh.puts "#{new_ip},#{1.hour.ago}"
    end
    assert_true(IpStats.blocked?(new_ip))
  end

  def test_okay_ips
    old_ip = "12.34.56.78"
    assert_true(IpStats.blocked?(old_ip))
    File.open(MO.okay_ips_file, "a") do |fh|
      fh.puts old_ip
    end
    assert_false(IpStats.blocked?(old_ip))
  end

  def test_clean_out_old_blocked_ips
    # All existing ips in fixture should already be old.
    new_ip = "24.68.35.79"
    IpStats.add_blocked_ips([new_ip])
    IpStats.clean_blocked_ips
    assert_equal([new_ip], IpStats.blocked_ips)
  end

  def test_add_blocked_ips
    old_ips = IpStats.blocked_ips
    # Oops!  Doesn't check if IP already added.
    # IpStats.add_blocked_ips(["1.0.0.1", "2.0.0.2", old_ips.first])
    IpStats.add_blocked_ips(["1.0.0.1", "2.0.0.2"])
    new_ips = IpStats.blocked_ips
    assert_equal(old_ips.length + 2, new_ips.length)
    assert_true(new_ips.include?("1.0.0.1"))
    assert_true(new_ips.include?("2.0.0.2"))
  end

  def test_remove_blocked_ips
    old_ips = IpStats.blocked_ips
    assert_true(old_ips.length > 2)
    IpStats.remove_blocked_ips([old_ips.first, old_ips.last, "9.9.9.9"])
    new_ips = IpStats.blocked_ips
    assert_equal(old_ips.length - 2, new_ips.length)
    assert_false(new_ips.include?(old_ips.first))
    assert_false(new_ips.include?(old_ips.last))
    assert_true(new_ips.include?(old_ips[1]))
  end

  def test_clear_bad_ips
    assert_not_empty(IpStats.blocked_ips)
    IpStats.clear_blocked_ips
    assert_empty(IpStats.blocked_ips)
  end

  def test_clear_okay_ips
    assert_not_empty(IpStats.read_okay_ips)
    IpStats.clear_okay_ips
    assert_empty(IpStats.read_okay_ips)
  end

  def test_add_okay_ips
    old_ips = IpStats.read_okay_ips
    # Oops!  Doesn't check if IP already added.
    # IpStats.add_okay_ips(["1.0.0.1", "2.0.0.2", old_ips.first])
    IpStats.add_okay_ips(["1.0.0.1", "2.0.0.2"])
    new_ips = IpStats.read_okay_ips
    assert_equal(old_ips.length + 2, new_ips.length)
    assert_true(new_ips.include?("1.0.0.1"))
    assert_true(new_ips.include?("2.0.0.2"))
  end

  def test_remove_okay_ips
    IpStats.add_okay_ips(["1.2.3.4"])
    old_ips = IpStats.read_okay_ips
    assert_true(old_ips.length > 1)
    assert_true(old_ips.include?("3.14.15.9"))
    IpStats.remove_okay_ips(["3.14.15.9", "9.9.9.9"])
    new_ips = IpStats.read_okay_ips
    assert_equal(old_ips.length - 1, new_ips.length)
    assert_false(new_ips.include?("3.14.15.9"))
    assert_true(new_ips.include?("1.2.3.4"))
  end

  def test_log_stats
    File.delete(MO.ip_stats_file) if File.exist?(MO.ip_stats_file)

    ip1 = "1.2.3.4"
    ip2 = "5.6.7.8"
    rolf = User.where(login: "rolf").first

    User.current = nil
    IpStats.log_stats(ip: ip1, time: 15.seconds.ago,
                      controller: "observer", action: "show_observation")
    IpStats.log_stats(ip: ip1, time: 12.seconds.ago,
                      controller: "observer", action: "show_observation")
    IpStats.log_stats(ip: ip1, time: 9.seconds.ago,
                      controller: "observer", action: "show_observation")
    IpStats.log_stats(ip: ip1, time: 6.seconds.ago,
                      controller: "observer", action: "show_observation")
    User.current = rolf
    IpStats.log_stats(ip: ip2, time: 2.seconds.ago,
                      controller: "observer", action: "create_observation")

    stats = IpStats.read_stats(:do_activity)
    assert_equal([ip1, ip2], stats.keys.sort)
    assert_nil(stats[ip1][:user])
    assert_equal(rolf.id, stats[ip2][:user])
    assert_operator(stats[ip1][:rate], :>, 0.01)
    assert_operator(stats[ip2][:rate], :<, 0.01)
    assert_operator(stats[ip1][:load], :>, 0.01)
    assert_operator(stats[ip2][:load], :<, 0.01)
    assert_equal(4, stats[ip1][:activity].length)
    assert_equal(1, stats[ip2][:activity].length)
    assert_operator(stats[ip2][:activity][0][0], :>=, 2.seconds.ago.to_s)
    assert_operator(stats[ip2][:activity][0][1], :>=, 2.seconds)
    assert_equal("observer", stats[ip2][:activity][0][2])
    assert_equal("create_observation", stats[ip2][:activity][0][3])
  end
end
