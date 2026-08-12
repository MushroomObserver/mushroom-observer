# frozen_string_literal: true

require("test_helper")

class FieldSlip::Extractor::ContextTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
    @project = projects(:eol_project)
  end

  def context_for(obs = @obs)
    FieldSlip::Extractor::Context.new(observation: obs)
  end

  def join_project
    @project.observations << @obs unless @project.observations.include?(@obs)
  end

  def test_for_image_uses_the_images_observation
    context = FieldSlip::Extractor::Context.for_image(@image.reload)

    assert_includes(@image.observations, context.observation)
  end

  def test_field_slip_code_comes_from_the_attached_slip
    assert_equal(@obs.field_slip&.code, context_for.field_slip_code)
  end

  # An observation can sit in several projects (the obs form pre-checks
  # the last one used); the attached slip says which event it belongs
  # to, and the aliases and template must follow the slip. Reported
  # against a NEMF slip reviewed through another project's aliases.
  def test_project_prefers_the_attached_slips_project
    join_project
    other = projects(:open_membership_project)
    # update_columns: a real project change cascades the observations
    # along; the test needs the divergence.
    @obs.field_slip.update_columns(project_id: other.id)

    assert_equal(other, context_for(@obs.reload).project)
  end

  def test_project_falls_back_to_the_observations_first_project
    join_project
    @obs.field_slip.update_columns(project_id: nil)

    assert_equal(@project, context_for(@obs.reload).project)
  end

  # The abbreviation table is the project's own aliases rather than
  # anything written into the prompt -- that is what lets an alias added
  # during review improve the next slip.
  def test_aliases_pair_names_with_their_targets
    join_project
    ProjectAlias.create!(project: @project, name: "9",
                         target: locations(:albion))

    pairs = context_for.aliases("Location")

    assert_includes(pairs, ["9", locations(:albion).name])
  end

  def test_user_aliases_use_the_legal_name
    join_project
    fixture = project_aliases(:one) # "RS" -> rolf, in eol_project

    assert_equal(@project, fixture.project, "premise: alias is on this project")
    assert_includes(context_for.aliases("User"),
                    [fixture.name, rolf.legal_name.presence || rolf.login])
  end

  # Newest first, so a corrected alias outranks a stale one when the
  # list is truncated for the prompt.
  def test_aliases_are_newest_first
    join_project
    older = ProjectAlias.create!(project: @project, name: "AAA",
                                 target: locations(:albion))
    newer = ProjectAlias.create!(project: @project, name: "BBB",
                                 target: locations(:burbank))
    older.update_columns(updated_at: 2.days.ago)
    newer.update_columns(updated_at: 1.hour.ago)

    names = context_for.aliases("Location").map(&:first)

    assert_operator(names.index("BBB"), :<, names.index("AAA"))
  end

  def test_aliases_empty_without_a_project
    # The fixture slip carries a project; "no project" now means the
    # slip's is gone too.
    @obs.field_slip.update_columns(project_id: nil)

    assert_empty(context_for(@obs.reload).aliases("Location"))
  end

  # An alias whose target has been deleted would otherwise render as a
  # blank row in the prompt, teaching the model nothing.
  def test_aliases_skip_targetless_entries
    join_project
    orphan = ProjectAlias.create!(project: @project, name: "Gone",
                                  target: locations(:albion))
    orphan.update_columns(target_id: 0)

    assert_not_includes(context_for.aliases("Location").map(&:first), "Gone")
  end

  # The event's own dates beat a hardcoded month: a slip dated outside
  # them is far more likely misread than real.
  def test_date_range_comes_from_the_project
    join_project
    @project.update!(start_date: Date.parse("2026-07-30"),
                     end_date: Date.parse("2026-08-02"))

    assert_equal(%w[2026-07-30 2026-08-02], context_for.date_range)
  end

  def test_date_range_nil_when_the_project_has_none
    join_project
    @project.update_columns(start_date: nil, end_date: nil)

    assert_nil(context_for.date_range)
  end

  def test_no_observation_is_survivable
    context = FieldSlip::Extractor::Context.new(observation: nil)

    assert_nil(context.project)
    assert_nil(context.field_slip_code)
    assert_nil(context.date_range)
    assert_empty(context.aliases("User"))
  end
end
