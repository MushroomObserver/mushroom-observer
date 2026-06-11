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
    obs.notes = {} # no legacy collector note
    fields = ObservationLabels::Fields.new(obs)

    obs.collector_user = users(:rolf)
    assert_equal(users(:rolf).legal_name, fields.send(:column_collector))

    obs.collector_user = nil
    obs.collector = "Jane Forager"
    assert_equal("Jane Forager", fields.send(:column_collector))

    obs.collector = nil
    assert_nil(fields.send(:column_collector))
  end

  # legal_name falls back to login when the linked user's name is blank.
  def test_column_collector_blank_name_uses_login
    obs = observations(:minimal_unknown_obs)
    user = users(:rolf)
    user.name = ""
    obs.collector_user = user
    fields = ObservationLabels::Fields.new(obs)
    assert_equal(user.login, fields.send(:column_collector))
  end

  # Expand-window fallback: column blank, collector still in notes.
  def test_column_collector_legacy_note_fallback
    obs = observations(:minimal_unknown_obs)
    obs.collector = nil
    obs.collector_user = nil
    obs.notes = { Collector: "_user rolf_" }
    fields = ObservationLabels::Fields.new(obs)
    assert_equal(users(:rolf).legal_name, fields.send(:column_collector))
  end
end
