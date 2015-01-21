# encoding: utf-8
require 'test_helper'

class RobotsTest < UnitTestCase
  def test_parse_robots_dot_text
    file = "#{::Rails.root}/test/fixtures/robots.txt"
    data = Robots.parse_robots_dot_text(file)
    assert_equal(["glossary/show_term", "species_list/show_species_list"],
                 data.keys.sort)
    assert_true(data["glossary/show_term"])
    assert_true(data["species_list/show_species_list"])
    assert_false(data["observer/really_long_query"])
  end
end
