# frozen_string_literal: true

require("test_helper")

class UserStatsTest < ActiveSupport::TestCase
  def test_user_data
    rolf = users(:rolf)
    user_stats = user_stats(:rolf)
    user_data = UserStats.get_user_data(rolf.id)

    user_stats.reload

    # Assert that get_user_data both updates the db and returns the stats
    assert_equal(user_data, user_stats)
    assert_equal(rolf.observations.size, user_data.observations)
    assert_equal(rolf.names.size, user_data.names)
    assert_equal(rolf.images.size, user_data.images)
    assert_equal(rolf.namings.size, user_data.namings)
  end

  def test_refresh_all_user_stats
    rolf = users(:rolf)
    UserStats.refresh_all_user_stats
    rolf_stats = UserStats.find_by(user_id: rolf.id)
    assert_equal(rolf.observations.size, rolf_stats.observations)
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
