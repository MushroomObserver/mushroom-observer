# frozen_string_literal: true

require("test_helper")

class FormObject::OccurrenceProjectsTest < UnitTestCase
  def test_attributes
    form = FormObject::OccurrenceProjects.new(
      resolution: "skip",
      primary_observation_id: 42,
      observation_ids: [1, 2, 3]
    )

    assert_equal("skip", form.resolution)
    assert_equal(42, form.primary_observation_id)
    assert_equal([1, 2, 3], form.observation_ids)
  end

  def test_observation_ids_defaults_to_empty_array
    assert_equal([], FormObject::OccurrenceProjects.new.observation_ids)
  end

  def test_primary_observation_id_coerces_to_integer
    form = FormObject::OccurrenceProjects.new(
      primary_observation_id: "42"
    )

    assert_equal(42, form.primary_observation_id)
  end

  # The form binds fields under this namespace; the controller reads
  # `params.dig(:occurrence_projects, ...)`. Locking the param_key in
  # so a rename triggers a test failure.
  def test_param_key_is_occurrence_projects
    assert_equal("occurrence_projects",
                 FormObject::OccurrenceProjects.model_name.param_key)
  end

  def test_not_persisted
    assert_not(FormObject::OccurrenceProjects.new.persisted?)
  end
end
