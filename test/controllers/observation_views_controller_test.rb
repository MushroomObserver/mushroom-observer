# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation views - test updating the `reviewed` column
# ------------------------------------------------------------
class ObservationViewsControllerTest < FunctionalTestCase
  def test_update
    login("mary")
    obs = Observation.needs_identification(users(:mary))
    obs_count = obs.count

    # Have to create the o_v, none existing
    obs.take(5).pluck(:id).each do |id|
      ObservationView.create({ observation_id: id,
                               user_id: users(:mary).id,
                               reviewed: true })
    end

    now_obs = Observation.needs_identification(users(:mary))
    now_obs_count = now_obs.count
    assert_equal(now_obs_count, obs_count - 5)
  end
end
