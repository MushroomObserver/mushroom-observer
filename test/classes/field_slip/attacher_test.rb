# frozen_string_literal: true

require("test_helper")

class FieldSlip::AttacherTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @obs.update!(occurrence: nil)
    # Prefix OPEN, open_membership true.
    @project = projects(:open_membership_project)
  end

  def attach(code:, user: @obs.user, obs: @obs)
    FieldSlip::Attacher.attach(observation: obs, code: code, user: user)
  end

  def test_attaches_a_new_slip_and_files_into_the_prefix_project
    user = @obs.user

    assert_not(@project.member?(user), "premise: not yet a member")

    result = attach(code: "OPEN-0219")

    assert_equal(:attached, result)
    @obs.reload

    assert_equal("OPEN-0219", @obs.field_slip.code)
    assert_equal(user, @obs.field_slip.user, "slip adopts the observer")
    assert(@project.member?(user), "using the slip enrolls the user")
    assert_includes(@project.observations.reload, @obs,
                    "the observation files into the prefix project")
  end

  def test_reuses_an_existing_unused_slip
    slip = FieldSlip.find_or_create_by_code("OPEN-0311", @obs.user)

    assert_equal(:attached, attach(code: "open-0311"))
    assert_equal(slip, @obs.reload.field_slip)
  end

  # Nobody is watching, so nothing that would move an observation or
  # claim another collector's slip is ever done automatically.
  def test_never_touches_an_observation_that_has_an_occurrence
    other = observations(:minimal_unknown_obs)
    slip = FieldSlip.find_or_create_by_code("OPEN-0400", other.user)
    other.field_slip = slip
    other.save!

    assert_equal(:already_linked, attach(obs: other.reload, code: "OPEN-0401"))
    assert_equal("OPEN-0400", other.reload.field_slip.code)
  end

  def test_never_joins_a_slip_already_in_use
    other = observations(:coprinus_comatus_obs)
    slip = FieldSlip.find_or_create_by_code("OPEN-0500", other.user)
    other.update!(occurrence: nil)
    other.field_slip = slip
    other.save!

    assert_equal(:in_use, attach(code: "OPEN-0500"))
    assert_nil(@obs.reload.occurrence)
  end

  # `join_in_use:` is the review form's human-confirmed resolution of
  # the in-use case: the observation joins the slip's occurrence and,
  # carrying the freshly reviewed data, becomes its primary.
  def test_join_in_use_joins_the_occurrence_and_takes_primary
    other = observations(:coprinus_comatus_obs)
    slip = FieldSlip.find_or_create_by_code("OPEN-0510", other.user)
    other.update!(occurrence: nil)
    other.field_slip = slip
    other.save!

    result = FieldSlip::Attacher.attach(observation: @obs, code: "OPEN-0510",
                                        user: @obs.user, join_in_use: true)

    assert_equal(:joined, result)
    @obs.reload

    assert_equal(slip.reload.occurrence, @obs.occurrence)
    assert_equal(@obs.id, @obs.occurrence.primary_observation_id)
    assert_includes(@obs.occurrence.observations, other.reload)
  end

  def test_join_in_use_refuses_a_full_occurrence
    other = observations(:coprinus_comatus_obs)
    slip = FieldSlip.find_or_create_by_code("OPEN-0511", other.user)
    other.update!(occurrence: nil)
    other.field_slip = slip
    other.save!

    # Filling a real occurrence to MAX_OBSERVATIONS is heavy; lower the
    # cap to the one member it already has instead.
    original = Occurrence::MAX_OBSERVATIONS
    Occurrence.send(:remove_const, :MAX_OBSERVATIONS)
    Occurrence.const_set(:MAX_OBSERVATIONS, 1)

    result = FieldSlip::Attacher.attach(
      observation: @obs, code: "OPEN-0511",
      user: @obs.user, join_in_use: true
    )

    assert_equal(:occurrence_full, result)
    assert_nil(@obs.reload.occurrence)
  ensure
    Occurrence.send(:remove_const, :MAX_OBSERVATIONS)
    Occurrence.const_set(:MAX_OBSERVATIONS, original)
  end

  # An existing slip in a project the user can neither join nor is a
  # member of: attaching would put the observation there against
  # invariant 4 (#4932).
  def test_skips_an_existing_slip_for_a_closed_project
    closed = projects(:bolete_project)

    assert_not(closed.open_membership, "premise: closed to self-joining")

    owner = closed.user_group.users.first
    slip = FieldSlip.find_or_create_by_code("BLT-0600", owner)

    assert_equal(closed, slip.project, "premise: slip landed in the project")

    stranger = users(:zero_user)

    assert_not(closed.member?(stranger), "premise: not a member")

    @obs.update!(user: stranger)

    assert_equal(:closed_project, attach(code: "BLT-0600", user: stranger))
    assert_nil(@obs.reload.occurrence)
  end

  # A NEW code for a closed project comes out as a spare: the slip is
  # created project-less (FieldSlip#update_project declines a project
  # the user can't add to), so the observation links to the slip but
  # joins no project. Same as typing the code into the observation form.
  def test_a_new_code_for_a_closed_project_becomes_a_spare_slip
    closed = projects(:bolete_project)
    stranger = users(:zero_user)
    @obs.update!(user: stranger)

    assert_equal(:attached, attach(code: "BLT-0700", user: stranger))
    @obs.reload

    assert_equal("BLT-0700", @obs.field_slip.code)
    assert_nil(@obs.field_slip.project)
    assert_not_includes(closed.observations.reload, @obs)
  end

  def test_an_unusable_code_is_invalid
    assert_equal(:invalid, attach(code: "12345"),
                 "all digits fails FieldSlip's code validation")
    assert_nil(@obs.reload.occurrence)
  end
end
