# frozen_string_literal: true

require("test_helper")

class UserStatsTest < UnitTestCase
  def rolfs_name_edits
    Name::Version.joins(:name).
      where(Name::Version.arel_table[:user_id].eq(rolf.id)).
      where.not(
        Name::Version.arel_table[:user_id].eq(Name[:user_id])
      ).distinct.select(Name::Version.arel_table[:name_id]).count
  end

  def test_get_user_data
    user_stats = user_stats(:rolf)
    assert_equal(0, user_stats.comments)
    assert_equal(0, user_stats.images)
    assert_equal(0, user_stats.locations)
    assert_equal(0, user_stats.names)
    assert_equal(0, user_stats.name_description_authors)
    assert_equal(0, user_stats.name_description_editors)
    assert_equal(0, user_stats.name_versions)
    assert_equal(0, user_stats.namings)
    assert_equal(0, user_stats.observations)
    assert_equal(0, user_stats.species_lists)
    assert_equal(0, user_stats.votes)

    # Assert that get_user_data both updates the db and returns the stats
    user_data = UserStats.get_user_data(rolf.id)
    assert_equal(user_data, user_stats.reload)

    assert_equal(rolf.comments.size, user_data.comments)
    assert_equal(rolf.images.size, user_data.images)
    assert_equal(rolf.locations.size, user_data.locations)
    assert_equal(rolf.names.size, user_data.names)
    assert_equal(rolf.name_description_authors.size,
                 user_data.name_description_authors)
    assert_equal(rolf.name_description_editors.size,
                 user_data.name_description_editors)
    assert_equal(rolfs_name_edits, user_data.name_versions)
    assert_equal(rolf.namings.size, user_data.namings)
    assert_equal(rolf.observations.size, user_data.observations)
    assert_equal(rolf.species_lists.size, user_data.species_lists)
    assert_equal(rolf.votes.size, user_data.votes)
  end

  def test_refresh_all_user_stats
    UserStats.refresh_all_user_stats
    rolf_stats = UserStats.find_by(user_id: rolf.id)
    assert_equal(rolf.comments.size, rolf_stats.comments)
    assert_equal(rolf.images.size, rolf_stats.images)
    assert_equal(rolf.locations.size, rolf_stats.locations)
    assert_equal(rolf.names.size, rolf_stats.names)
    assert_equal(rolf.name_description_authors.size,
                 rolf_stats.name_description_authors)
    assert_equal(rolf.name_description_editors.size,
                 rolf_stats.name_description_editors)
    assert_equal(rolfs_name_edits, rolf_stats.name_versions)
    assert_equal(rolf.namings.size, rolf_stats.namings)
    assert_equal(rolf.observations.size, rolf_stats.observations)
    assert_equal(rolf.species_lists.size, rolf_stats.species_lists)
    assert_equal(rolf.votes.size, rolf_stats.votes)

    mary_stats = UserStats.find_by(user_id: mary.id)
    assert_equal(mary.comments.size, mary_stats.comments)
    assert_equal(mary.images.size, mary_stats.images)
    assert_equal(mary.locations.size, mary_stats.locations)
    assert_equal(mary.names.size, mary_stats.names)
    assert_equal(mary.name_description_authors.size,
                 mary_stats.name_description_authors)
    assert_equal(mary.name_description_editors.size,
                 mary_stats.name_description_editors)
    assert_equal(mary.namings.size, mary_stats.namings)
    assert_equal(mary.observations.size, mary_stats.observations)
    assert_equal(mary.species_lists.size, mary_stats.species_lists)

    mary_splo = SpeciesList.joins(:species_list_observations).
                where(user_id: mary.id).count
    assert_equal(mary_splo, mary_stats.species_list_entries)
    assert_equal(mary.votes.size, mary_stats.votes)
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
