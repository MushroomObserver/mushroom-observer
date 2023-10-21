# frozen_string_literal: true

require("test_helper")

class ObservationViewTest < UnitTestCase
  def test_basic_stuff
    obs = observations(:minimal_unknown_obs)
    assert_empty(ObservationView.where(observation_id: obs.id,
                                       user_id: dick.id))
    ObservationView.update_view_stats(obs.id, dick.id)
    assert_equal(1,
                 ObservationView.where(observation_id: obs.id,
                                       user_id: dick.id).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
  end
end
