# frozen_string_literal: true

require("test_helper")

class Search::ObservationsTest < UnitTestCase
  def test_create_observation_filter_from_session
    pattern = "something"
    terms = Query.lookup(:Observation, pattern:).params
    filter = Search::Observations.new(terms)
    assert_equal(pattern, filter.pattern)
  end
end
