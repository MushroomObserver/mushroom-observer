# frozen_string_literal: true

require("test_helper")

class ObservationFilterTest < UnitTestCase
  def test_create_observation_filter_from_session
    pattern = "something"
    terms = PatternSearch::Observation.new(pattern).form_params
    filter = ObservationFilter.new(terms)
    assert_equal(pattern, filter.pattern)
  end
end
