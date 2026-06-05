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

  def test_column_collector
    obs = observations(:minimal_unknown_obs)
    fields = ObservationLabels::Fields.new(obs)

    obs.collector_user = users(:rolf)
    assert_equal(users(:rolf).name, fields.send(:column_collector))

    obs.collector_user = nil
    obs.collector = "Jane Forager"
    assert_equal("Jane Forager", fields.send(:column_collector))

    obs.collector = nil
    assert_nil(fields.send(:column_collector))
  end
end
