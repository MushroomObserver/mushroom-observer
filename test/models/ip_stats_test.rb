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
end
