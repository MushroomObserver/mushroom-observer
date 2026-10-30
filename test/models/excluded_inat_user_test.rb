# frozen_string_literal: true

require("test_helper")

class ExcludedInatUserTest < UnitTestCase
  def test_login_is_normalized_and_validated
    entry = ExcludedInatUser.create!(inat_login: "  Some_Photographer ")
    assert_equal("some_photographer", entry.inat_login)

    assert_not(ExcludedInatUser.new(inat_login: "some_photographer").valid?,
               "A login should be listed once")
    assert_not(ExcludedInatUser.new(inat_login: "no spaces").valid?,
               "A login should look like an iNat login")
    assert_not(ExcludedInatUser.new(inat_login: nil).valid?)
  end

  def test_an_mo_users_login_is_refused
    users(:rolf).update!(inat_username: "rolf_on_inat")

    entry = ExcludedInatUser.new(inat_login: "rolf_on_inat")

    assert_not(entry.valid?, "An MO user opts out on their profile")
    assert(entry.errors.added?(:inat_login, :excluded_inat_user_has_account))
  end

  def test_matching_records_the_id_and_then_matches_on_it
    entry = ExcludedInatUser.create!(inat_login: "old_login")

    assert_equal(entry, ExcludedInatUser.matching(login: "Old_Login", id: 42))
    assert_equal(42, entry.reload.inat_user_id)
    assert_equal(entry, ExcludedInatUser.matching(login: "new_login", id: 42),
                 "The id should match after a login change")
    assert_nil(ExcludedInatUser.matching(login: "someone_else", id: 7))
  end

  # The setting moves to the profile when an MO user claims the login.
  def test_a_user_claiming_the_login_takes_over_the_setting
    ExcludedInatUser.create!(inat_login: "mary_on_inat")
    mary = users(:mary)

    mary.update!(inat_username: "Mary_On_iNat")

    assert(mary.reload.inat_import_opt_out)
    assert_not(ExcludedInatUser.exists?(inat_login: "mary_on_inat"))
  end

  def test_opt_out_covers_profile_and_list
    users(:rolf).update!(inat_username: "rolf_on_inat",
                         inat_import_opt_out: true)
    ExcludedInatUser.create!(inat_login: "listed")

    assert(Inat::OptOut.opted_out?({ login: "Rolf_On_iNat", id: 1 }))
    assert(Inat::OptOut.opted_out?({ login: "listed", id: 2 }))
    assert_not(Inat::OptOut.opted_out?({ login: "anyone", id: 3 }))
    users(:rolf).update!(inat_import_opt_out: false)
    assert_not(Inat::OptOut.opted_out?({ login: "rolf_on_inat", id: 1 }),
               "A linked account alone is not an opt-out")
  end
end
