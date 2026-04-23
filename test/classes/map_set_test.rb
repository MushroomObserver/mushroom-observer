# frozen_string_literal: true

require("test_helper")

class MapSetTest < UnitTestCase
  # ------------------------------------------------------------------
  # #compute_color — issue #4159 (was #4131)
  # ------------------------------------------------------------------

  # Location-only sets have no observations to classify; they keep the
  # neutral blue and the legend is suppressed on maps with no obs.
  def test_color_location_only_for_no_observations
    set = set_of(locations(:burbank))
    assert_equal(Mappable::MapSet::LOCATION_ONLY_COLOR, set.compute_color)
  end

  def test_color_confirmed_for_single_obs_confirmed
    # 2.4 / 3 * 100 = 80.0 — exactly the threshold.
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 2.4))
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, set.compute_color)
  end

  def test_color_tentative_for_single_obs_tentative
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 1.5))
    assert_equal(Mappable::MapSet::TENTATIVE_COLOR, set.compute_color)
  end

  def test_color_disputed_for_single_obs_at_zero
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 0.0))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  def test_color_disputed_for_single_obs_negative
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: -1.5))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  def test_color_disputed_for_single_obs_missing_vote_cache
    # Vote.percent returns 0.0 when vote_cache is blank -> disputed.
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: nil))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  # Multi-obs sets: same-band members take that band's color.
  def test_color_confirmed_when_all_members_confirmed
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 3.0),
                 build_obs(lat: 10, lng: 10, vote_cache: 2.4))
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, set.compute_color)
  end

  def test_color_disputed_when_all_members_disputed
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: -1.0),
                 build_obs(lat: 10, lng: 10, vote_cache: 0.0))
    assert_equal(Mappable::MapSet::DISPUTED_COLOR, set.compute_color)
  end

  # Mixed-band members use MIXED_COLOR.
  def test_color_mixed_when_members_in_different_bands
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 3.0),
                 build_obs(lat: 10, lng: 10, vote_cache: 1.5))
    assert_equal(Mappable::MapSet::MIXED_COLOR, set.compute_color)
  end

  def test_color_mixed_with_confirmed_plus_disputed
    set = set_of(build_obs(lat: 10, lng: 10, vote_cache: 3.0),
                 build_obs(lat: 10, lng: 10, vote_cache: -1.0))
    assert_equal(Mappable::MapSet::MIXED_COLOR, set.compute_color)
  end

  # On the observations index map the controller passes obs AND their
  # locations. CollapsibleCollectionOfObjects can put a single obs and
  # its location in the same bucket, giving @objects.size == 2 even
  # though there's just one observation. The set should still color
  # by that observation's consensus.
  def test_color_for_single_obs_bucketed_with_its_location
    obs = build_obs(lat: 34.1, lng: -118.3, vote_cache: 2.4)
    set = set_of(obs, locations(:burbank))
    assert_equal(1, set.observations.length)
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, set.compute_color,
                 "Single obs bucketed with its location should still " \
                 "use the consensus color, not LOCATION_ONLY_COLOR")
  end

  # ------------------------------------------------------------------
  # #compute_glyph — issue #4159 ("dot = single, square = multiple")
  # ------------------------------------------------------------------

  def test_glyph_dot_for_single_observation
    set = set_of(build_obs(lat: 10, lng: 10))
    assert_equal(:dot, set.compute_glyph)
  end

  def test_glyph_square_for_multiple_observations
    set = set_of(build_obs(lat: 10, lng: 10),
                 build_obs(lat: 10, lng: 10))
    assert_equal(:square, set.compute_glyph)
  end

  def test_glyph_square_for_location_only
    set = set_of(locations(:burbank))
    assert_equal(:square, set.compute_glyph)
  end

  def test_glyph_dot_for_single_obs_bucketed_with_its_location
    set = set_of(build_obs(lat: 34.1, lng: -118.3),
                 locations(:burbank))
    assert_equal(:dot, set.compute_glyph,
                 "One obs bucketed with its location is still a single obs")
  end

  # ------------------------------------------------------------------
  # #compute_border_style — issue #4159
  # ------------------------------------------------------------------

  def test_border_crisp_when_single_obs_has_gps
    set = set_of(build_obs(lat: 10, lng: 10))
    assert_equal(:crisp, set.compute_border_style)
  end

  def test_border_none_when_single_obs_has_no_gps
    # Location-only positioning — no lat/lng on the obs.
    obs = Mappable::MinimalObservation.new(
      id: 999, lat: nil, lng: nil,
      location: locations(:burbank),
      name_id: 1, text_name: "Test", when: Time.zone.today,
      vote_cache: 3.0
    )
    set = set_of(obs)
    assert_equal(:none, set.compute_border_style)
  end

  def test_border_crisp_when_all_members_have_gps
    set = set_of(build_obs(lat: 10, lng: 10),
                 build_obs(lat: 10.01, lng: 10.01))
    assert_equal(:crisp, set.compute_border_style)
  end

  def test_border_none_when_no_member_has_gps
    a = Mappable::MinimalObservation.new(
      id: 1, lat: nil, lng: nil, location: locations(:burbank),
      name_id: 1, text_name: "A", when: Time.zone.today, vote_cache: 3.0
    )
    b = Mappable::MinimalObservation.new(
      id: 2, lat: nil, lng: nil, location: locations(:burbank),
      name_id: 1, text_name: "B", when: Time.zone.today, vote_cache: 3.0
    )
    set = set_of(a, b)
    assert_equal(:none, set.compute_border_style)
  end

  def test_border_dashed_when_members_are_mixed_precision
    precise = build_obs(lat: 34.1, lng: -118.3)
    fuzzy = Mappable::MinimalObservation.new(
      id: 999, lat: nil, lng: nil, location: locations(:burbank),
      name_id: 1, text_name: "Fuzzy", when: Time.zone.today,
      vote_cache: 3.0
    )
    set = set_of(precise, fuzzy)
    assert_equal(:dashed, set.compute_border_style)
  end

  def test_border_crisp_for_location_only_set
    set = set_of(locations(:burbank))
    assert_equal(:crisp, set.compute_border_style)
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  private

  # Deterministic id counter so tests don't depend on RNG state.
  def next_obs_id
    @next_obs_id = (@next_obs_id || 0) + 1
  end

  def build_obs(lat:, lng:, vote_cache: 3.0)
    Mappable::MinimalObservation.new(
      id: next_obs_id, lat: lat, lng: lng,
      name_id: 1, text_name: "Test name",
      when: Time.zone.today, vote_cache: vote_cache
    )
  end

  def set_of(*objects)
    Mappable::MapSet.new(objects)
  end
end
