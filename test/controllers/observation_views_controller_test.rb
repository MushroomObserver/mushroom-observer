# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation views - test updating the `reviewed` column
# ------------------------------------------------------------
class ObservationViewsControllerTest < FunctionalTestCase
  def test_update
    login("mary")
    obs = Observation.needs_naming_and_not_reviewed_by_user(users(:mary))
    obs_count = obs.count

    # Have to create the o_v, none existing
    obs.take(5).pluck(:id).each do |id|
      put(:update, params: { id: id, reviewed: "1" })
      assert_redirected_to(identify_observations_path)
    end

    now_obs = Observation.needs_naming_and_not_reviewed_by_user(users(:mary))
    now_obs_count = now_obs.count
    assert_equal(obs_count - 5, now_obs_count)
  end
end
