# frozen_string_literal: true

require("test_helper")

class ObservationFieldsTest < UnitTestCase
  def test_error_case
    Location.update_box_area_and_center_columns
    obs = observations(:suillus_weaverae_obs)
    obs_fields = ObservationFields.new(obs)
    similar_obs = obs_fields.similar_observations
    assert_includes(similar_obs, observations(:dup_suillus_weaverae_obs))
    assert_includes(similar_obs, observations(:nearby_suillus_weaverae_obs))
    assert_not_includes(similar_obs, observations(:faraway_suillus_weaverae_obs))
    assert_not_includes(similar_obs, observations(:older_suillus_weaverae_obs))
    assert_not_includes(similar_obs, observations(:suillus_granulatus_obs))
  end
end
