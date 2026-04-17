# frozen_string_literal: true

require("test_helper")

class MapSetTest < UnitTestCase
  # ------------------------------------------------------------------
  # #compute_color — issue #4131
  # ------------------------------------------------------------------

  def test_color_blue_for_multi_observation_group
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 3.0),
                 build_obs(lat: 10, lng: 10, vote_cache: 3.0))
    assert_equal(Mappable::MapSet::GROUP_COLOR, set.compute_color)
  end

  def test_color_blue_for_location_only
    set = set_of(locations(:burbank))
    assert_equal(Mappable::MapSet::GROUP_COLOR, set.compute_color)
  end

  def test_color_green_for_single_obs_confirmed
    # 2.4 / 3 * 100 = 80.0 — exactly the threshold.
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 2.4))
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, set.compute_color)
  end

  def test_color_orange_for_single_obs_tentative
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 1.5))
    assert_equal(Mappable::MapSet::TENTATIVE_COLOR, set.compute_color)
  end

  def test_color_red_for_single_obs_disputed_at_zero
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 0.0))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  def test_color_red_for_single_obs_negative
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: -1.5))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  def test_color_red_for_single_obs_missing_vote_cache
    # Vote.percent returns 0.0 when the value is blank -> disputed.
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: nil))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  # On the observations index map the controller passes obs AND their
  # locations. CollapsibleCollectionOfObjects can put a single obs and
  # its location in the same bucket, giving @objects.size == 2 even
  # though there's just one observation. The set should still colour
  # by that observation's consensus, not blue.
  def test_color_for_single_obs_bucketed_with_its_location
    obs = build_obs(lat: 34.1, lng: -118.3, vote_cache: 2.4)
    set = set_of(obs, locations(:burbank))
    assert_equal(1, set.observations.length)
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, set.compute_color,
                 "Single obs bucketed with its location should still " \
                 "use the consensus color, not GROUP_COLOR")
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  private

  def build_obs(lat:, lng:, vote_cache: 3.0)
    Mappable::MinimalObservation.new(
      id: rand(1_000_000), lat: lat, lng: lng,
      name_id: 1, text_name: "Test name",
      when: Time.zone.today, vote_cache: vote_cache
    )
  end

  def set_of(*objects)
    Mappable::MapSet.new(objects)
  end
end
