require "test_helper"

class IpStatsTest < UnitTestCase
  def test_blocked_ips
    file1 = MO.blocked_ips_file
    file2 = MO.okay_ips_file
    file1_tmp = file1 + ".tmp"
    file2_tmp = file2 + ".tmp"

    assert_true(IpStats.blocked?("12.34.56.78"))
    assert_false(IpStats.blocked?("87.65.43.21"))
    assert_false(IpStats.blocked?("3.14.15.9"))

    File.rename(file1, file1_tmp)
    system("echo 87.65.43.21 > #{file1}")
    assert_true(IpStats.blocked?("87.65.43.21"))

    File.rename(file2, file2_tmp)
    # Make IpStats recognize that following modification of okay_ips_file is
    # later than in-memory modification of list of blocked ips
    sleep(1)
    system("echo 87.65.43.21 > #{file2}")
    assert_false(IpStats.blocked?("87.65.43.21"))

  ensure
    if File.exist?(file1_tmp)
      File.delete(file1) if File.exist?(file1)
      File.rename(file1_tmp, file1)
    end
    if File.exist?(file2_tmp)
      File.delete(file2) if File.exist?(file2)
      File.rename(file2_tmp, file2)
    end
  end
end
