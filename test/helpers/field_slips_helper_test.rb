# frozen_string_literal: true

require("test_helper")

class FieldSlipsHelperTest < ActionView::TestCase
  include FieldSlipsHelper

  def test_previous_observation_returns_nil_when_no_user
    obs = observations(:minimal_unknown_obs)

    assert_nil(previous_observation(obs, nil),
               "Expected nil when user is nil")
  end

  def test_previous_observation_queries_observation_views_when_user_present
    obs = observations(:minimal_unknown_obs)
    user = users(:rolf)

    result = previous_observation(obs, user)
    assert_nil(result,
               "Expected nil when user has no prior observation views")
  end
end
