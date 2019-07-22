require "test_helper"

class RobotsTest < UnitTestCase
  def test_robots_dot_text
    file = MO.robots_dot_text_file
    data = Robots.parse_robots_dot_text(file)
    assert_equal(["glossary/show_term", "observer/intro"], data.keys.sort)
    assert_true(data["glossary/show_term"])
    assert_true(data["observer/intro"])
    assert_false(data["name/really_long_query"])
  end

  def test_blocked_ips
    file1 = MO.blocked_ips_file
    file2 = MO.okay_ips_file
    file1_tmp = file1 + ".tmp"
    file2_tmp = file2 + ".tmp"

    assert_true(Robots.blocked?("12.34.56.78"))
    assert_false(Robots.blocked?("87.65.43.21"))
    assert_false(Robots.blocked?("3.14.15.9"))

    File.rename(file1, file1_tmp)
    system("echo 87.65.43.21 > #{file1}")
    assert_true(Robots.blocked?("87.65.43.21"))

    File.rename(file2, file2_tmp)
    system("echo 87.65.43.21 > #{file2}")
    assert_false(Robots.blocked?("87.65.43.21"))

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
