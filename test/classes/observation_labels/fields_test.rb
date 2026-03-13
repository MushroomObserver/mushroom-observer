# frozen_string_literal: true

require("test_helper")

class FieldsTest < UnitTestCase
  def test_error_case
    Location.update_box_area_and_center_columns
    obs = observations(:megacollybia_rodmanii_obs)
    obs_fields = ObservationLabels::Fields.new(obs)
    similar_obs = obs_fields.similar_observations
    assert_includes(similar_obs, observations(:dup_megacollybia_rodmanii_obs))
    assert_includes(similar_obs,
                    observations(:nearby_megacollybia_rodmanii_obs))
    assert_not_includes(similar_obs,
                        observations(:faraway_megacollybia_rodmanii_obs))
    assert_not_includes(similar_obs,
                        observations(:older_megacollybia_rodmanii_obs))
    assert_not_includes(similar_obs,
                        observations(:megacollybia_platyphylla_obs))
  end
end
