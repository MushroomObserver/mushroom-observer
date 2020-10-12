# frozen_string_literal: true

require("test_helper")

class ObservationViewTest < UnitTestCase
  def test_basic_stuff
    obs = observations(:minimal_unknown_obs)
    assert_empty(ObservationView.where(observation: obs, user: dick))
    ObservationView.update_view_stats(obs, dick)
    assert_equal(1, ObservationView.where(observation: obs, user: dick).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
  end
end
