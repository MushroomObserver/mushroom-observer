# frozen_string_literal: true

require("test_helper")

class InatProjectSlipStandardizerTest < UnitTestCase
  def setup
    @project = projects(:open_membership_project) # prefix OPEN
    @import = inat_imports(:rolf_inat_import)
    @import.update!(project: @project)
    @user = @import.user
  end

  def standardizer
    Inat::ProjectSlipStandardizer.new(@import)
  end

  def import_obs(fixture)
    obs = observations(fixture)
    obs.update_column(:occurrence_id, nil)
    obs.update!(inat_import: @import, reflected_at: Time.zone.now)
    obs
  end

  def native_with_slip(fixture, code:, citing:)
    obs = observations(fixture)
    obs.update_column(:occurrence_id, nil)
    obs.update!(field_slip: FieldSlip.find_or_create_by_code(code, @user))
    obs.update!(notes: { Other: "iNat #{citing}" })
    obs
  end

  def test_inactive_without_a_project
    @import.update!(project: nil)
    obs = import_obs(:minimal_unknown_obs)

    standardizer.standardize(obs, inat_id: "111222333")

    assert_not(standardizer.active?)
    assert_not_includes(@project.observations.reload, obs)
  end

  def test_bare_observation_joins_the_project
    obs = import_obs(:minimal_unknown_obs)

    standardizer.standardize(obs, inat_id: "111222333")

    assert_includes(@project.observations.reload, obs)
  end

  def test_joins_native_partner_occurrence
    inat_id = "987654321"
    native = native_with_slip(:coprinus_comatus_obs, code: "OPEN-9001",
                                                     citing: inat_id)
    obs = import_obs(:detailed_unknown_obs)

    standardizer.standardize(obs, inat_id: inat_id)

    obs.reload
    assert_equal(native.reload.occurrence_id, obs.occurrence_id,
                 "Import observation should join the native's occurrence")
    assert_equal(native.id, obs.occurrence.primary_observation_id,
                 "The native member stays the occurrence's primary")
    assert_includes(@project.observations.reload, obs)
  end

  def test_merges_reused_slip_occurrence_into_native
    inat_id = "987650001"
    native = native_with_slip(:coprinus_comatus_obs, code: "OPEN-9005",
                                                     citing: inat_id)
    obs = import_obs(:detailed_unknown_obs)
    obs.update!(field_slip: FieldSlip.find_or_create_by_code("EOL-9005",
                                                             @user))

    standardizer.standardize(obs, inat_id: inat_id)

    obs.reload
    assert_equal(native.reload.occurrence_id, obs.occurrence_id,
                 "The reused slip's occurrence should merge into the " \
                 "native's; its correct slip wins")
    assert_equal("OPEN-9005", obs.occurrence.field_slip.code)
  end

  def test_reassigns_wrong_project_slip
    obs = import_obs(:minimal_unknown_obs)
    slip = FieldSlip.find_or_create_by_code("EOL-9002", @user)
    obs.update!(field_slip: slip)

    standardizer.standardize(obs, inat_id: "111222444")

    assert_equal(@project.id, slip.reload.project_id,
                 "A slip from another prefix moves to the target project")
    assert_includes(@project.observations.reload, obs)
  end

  def test_attaches_target_prefix_code_from_notes
    obs = import_obs(:minimal_unknown_obs)
    obs.update!(notes: { Other: "wrote code OPEN-9003 on the slip" })

    standardizer.standardize(obs, inat_id: "111222555")

    assert_equal("OPEN-9003", obs.reload.occurrence&.field_slip&.code,
                 "The code written in the notes should attach its slip")
    assert_includes(@project.observations.reload, obs)
  end

  def test_notes_code_join_keeps_native_primary
    native = observations(:coprinus_comatus_obs)
    native.update_column(:occurrence_id, nil)
    native.update!(field_slip: FieldSlip.find_or_create_by_code("OPEN-9004",
                                                                @user))
    obs = import_obs(:detailed_unknown_obs)
    obs.update!(notes: { Other: "slip OPEN-9004" })

    standardizer.standardize(obs, inat_id: "111222666")

    occurrence = obs.reload.occurrence
    assert_equal(native.reload.occurrence_id, occurrence.id)
    assert_equal(native.id, occurrence.primary_observation_id,
                 "A reflection joining an in-use slip must not stay primary")
  end

  def test_non_admin_constraint_violation_is_recorded_not_added
    @project.update!(start_date: Date.new(2020, 1, 1),
                     end_date: Date.new(2020, 1, 2))
    assert_not(@project.is_admin?(@user), "premise: importer is not admin")
    obs = import_obs(:minimal_unknown_obs)
    obs.update!(when: Date.new(2024, 6, 1))

    standardizer.standardize(obs, inat_id: "111222777")

    assert_not_includes(@project.observations.reload, obs)
    assert_includes(@import.reload.constraint_violation_obs_ids, obs.id)
  end

  def test_admin_import_adds_despite_constraints
    @project.update!(start_date: Date.new(2020, 1, 1),
                     end_date: Date.new(2020, 1, 2))
    admin = @project.admin_group.users.first
    assert(admin, "premise: project has an admin")
    @import.update!(user: admin)
    obs = import_obs(:minimal_unknown_obs)
    obs.update!(when: Date.new(2024, 6, 1))

    standardizer.standardize(obs, inat_id: "111222888")

    assert_includes(@project.observations.reload, obs)
    assert_empty(@import.reload.constraint_violation_obs_ids)
  end

  def test_reconcile_after_attach_reassigns_slip_and_membership
    obs = import_obs(:minimal_unknown_obs)
    slip = FieldSlip.find_or_create_by_code("EOL-9006", @user)
    obs.update!(field_slip: slip)

    Inat::ProjectSlipStandardizer.reconcile_after_attach(obs)

    assert_equal(@project.id, slip.reload.project_id)
    assert_includes(@project.observations.reload, obs)
  end

  def test_reconcile_after_attach_ignores_non_import_observations
    obs = observations(:minimal_unknown_obs)
    obs.update_column(:occurrence_id, nil)
    slip = FieldSlip.find_or_create_by_code("EOL-9007", @user)
    obs.update!(field_slip: slip)

    Inat::ProjectSlipStandardizer.reconcile_after_attach(obs)

    assert_not_equal(@project.id, slip.reload.project_id)
  end
end
