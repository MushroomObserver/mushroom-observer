require "test_helper"

class RobotsTest < UnitTestCase
  def test_parse_robots_dot_text
    file = "#{::Rails.root}/test/fixtures/robots.txt"
    data = Robots.parse_robots_dot_text(file)
    assert_equal(["glossary/show_term", "observer/intro"], data.keys.sort)
    assert_true(data["glossary/show_term"])
    assert_true(data["observer/intro"])
    assert_false(data["name/really_long_query"])
  end

  def test_parse_blocked_ips
    file = "#{::Rails.root}/test/fixtures/blocked_ips.txt"
    data = Robots.parse_blocked_ips(file)
    assert_true(Robots.blocked?("12.34.56.78"))
    assert_false(Robots.blocked?("87.65.43.21"))
  end
end
