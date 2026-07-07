# frozen_string_literal: true

require("test_helper")

class FieldSlipTest < UnitTestCase
  def test_prefix_for_code
    assert_equal("EOL", FieldSlip.prefix_for_code("EOL-1"))
    assert_equal("EOL", FieldSlip.prefix_for_code("EOL 1"))
    assert_equal("2026-NAMABC", FieldSlip.prefix_for_code("2026-NAMABC-001"))
    assert_nil(FieldSlip.prefix_for_code("EOL"), "No sequence number -> nil")
    assert_nil(FieldSlip.prefix_for_code(""))
  end

  # find_or_create_by_code derives the project from the code prefix, so a
  # slip created lazily (when an observation with a field_code is saved,
  # rather than up front in the field-slip form) still lands in its project.
  def test_find_or_create_by_code_derives_project_from_prefix
    # open_membership_project has prefix OPEN and lets anyone join, so
    # can_add_field_slip? holds for any user.
    slip = FieldSlip.find_or_create_by_code("OPEN-99999", rolf)

    assert_predicate(slip, :persisted?)
    assert_equal(projects(:open_membership_project), slip.project)
  end

  def test_find_or_create_by_code_returns_nil_for_invalid_code
    assert_nil(FieldSlip.find_or_create_by_code("12345", rolf),
               "digits-only code fails validation")
  end

  # eol_project: admins rolf + mary; members rolf, mary (editing),
  # katrina (no_trust); dick is not a member. See #4436.
  def test_admin_can_edit_trusting_members_slip
    slip = field_slips(:field_slip_one) # eol_project, owner mary (editing)

    assert(slip.can_edit?(rolf),
           "eol admin should edit a trusting member's field slip")
  end

  def test_admin_cannot_edit_no_trust_members_slip
    slip = field_slips(:field_slip_no_trust) # owner katrina (no_trust)

    assert_not(slip.can_edit?(rolf))
  end

  def test_admin_cannot_edit_non_members_slip
    # A slip associated with a project but owned by a non-member must not
    # be editable by the project's admins (privilege-escalation guard).
    eol = projects(:eol_project)
    assert_not(eol.member?(dick))
    slip = FieldSlip.create!(code: "EOL-7001", user: dick)
    slip.update_column(:project_id, eol.id)

    assert_not(slip.can_edit?(rolf),
               "Project admin must not edit a non-member's field slip")
  end
end
