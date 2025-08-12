# frozen_string_literal: true

require("test_helper")

class Search::NamesTest < UnitTestCase
  def test_create_name_search_from_session
    pattern = "something"
    terms = Query.lookup(:Name, pattern:).params
    filter = Search::Names.new(terms)
    assert_equal(pattern, filter.pattern)
  end
end
