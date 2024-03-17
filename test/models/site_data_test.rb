# frozen_string_literal: true

require("test_helper")

class SiteDataTest < UnitTestCase
  def test_site_data
    # Create unverified user so that counts of users, verfied users,
    # and contributing users are different
    unverified_user = User.create(
      login: "mkcwqwv",
      email: "anastasiyaskakun93@rambler.ru",
      password: "UveBeenPwned",
      password_confirmation: "UveBeenPwned"
    )
    assert_not(unverified_user.verified)
    verified_user_count = User.where.not(verified: nil).count
    assert_not_equal(User.count, verified_user_count)

    site_data = SiteData.new.get_site_data

    # assert_equal(verified_user_count, site_data[:users])
    assert_equal(User.where.not(contribution: 0).count,
                 site_data[:contributing_users])
    assert_equal(Sequence.count, site_data[:sequences])
    assert_equal(Sequence.distinct.count(:observation_id),
                 site_data[:sequenced_observations])
  end
end
