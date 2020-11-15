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
    unverified_user_count = User.where.not(verified: nil).count
    assert_not_equal(User.count, unverified_user_count)

    site_data = SiteData.new.get_site_data

    assert_equal(unverified_user_count, site_data[:users])
    assert_equal(
      User.where.not(contribution: 0).count,
      site_data[:contributing_users]
    )
    assert_equal(Sequence.count, site_data[:sequences])
  end

  def test_user_data
    user_data = SiteData.new.get_user_data(rolf.id)
  end

  def test_all_user_data
    all_user_data = SiteData.new.get_all_user_data

    assert_equal(User.count, all_user_data.length)
  end

  # def test_two_tiered_observation_scoring
  #   score = rolf.contribution
  #
  #   User.current = rolf
  #   obs = Observation.create!(
  #     :name => names(:fungi),
  #     :specimen => true,
  #     :notes => '1234567890',
  #     :thumb_image => Image.first
  #   )
  #   User.current = mary
  #   rolf.reload
  #   assert_objs_equal(obs, Observation.last)
  #   assert_users_equal(rolf, obs.user)
  #   assert_equal(score + 10, rolf.contribution)
  #
  #   obs.update_attribute(:specimen, false)
  #   rolf.reload
  #   assert_equal(score + 1, rolf.contribution)
  #
  #   obs.update_attribute(:specimen, true)
  #   rolf.reload
  #   assert_equal(score + 10, rolf.contribution)
  #
  #   obs.update_attribute(:notes, '123456789')
  #   rolf.reload
  #   assert_equal(score + 1, rolf.contribution)
  #
  #   obs.update_attribute(:notes, '1234567890')
  #   rolf.reload
  #   assert_equal(score + 10, rolf.contribution)
  #
  #   obs.update_attribute(:thumb_image, nil)
  #   rolf.reload
  #   assert_equal(score + 1, rolf.contribution)
  #
  #   obs.update_attribute(:thumb_image, Image.last)
  #   rolf.reload
  #   assert_equal(score + 10, rolf.contribution)
  #
  #   obs.destroy
  #   rolf.reload
  #   assert_equal(score + 0, rolf.contribution)
  #
  #   User.current = rolf
  #   obs = Observation.create!(
  #     :name => names(:fungi)
  #   )
  #   User.current = mary
  #   rolf.reload
  #   assert_equal(score + 1, rolf.contribution)
  #
  #   obs.destroy
  #   rolf.reload
  #   assert_equal(score + 0, rolf.contribution)
  # end
end
