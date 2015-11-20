# encoding: utf-8
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
end
