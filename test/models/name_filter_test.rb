# frozen_string_literal: true

require("test_helper")

class NameFilterTest < UnitTestCase
  def test_create_name_filter_from_session
    pattern = "something"
    terms = PatternSearch::Name.new(pattern).form_params
    filter = NameFilter.new(terms)
    assert_equal(pattern, filter.pattern)
  end
end
