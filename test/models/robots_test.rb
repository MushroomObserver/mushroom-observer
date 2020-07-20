# frozen_string_literal: true

require "test_helper"

class RobotsTest < UnitTestCase
  def test_robots_dot_text
    file = MO.robots_dot_text_file
    data = Robots.parse_robots_dot_text(file)
    assert_equal(["glossary_term/show", "info/intro"], data.keys.sort)
    assert_true(data["glossary_term/show"])
    assert_true(data["info/intro"])
    assert_false(data["name/really_long_query"])
  end
end
