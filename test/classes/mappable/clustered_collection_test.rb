# frozen_string_literal: true

require("test_helper")

# Focused unit tests for `Mappable::ClusteredCollection`. The component-
# level tests in `test/components/map_test.rb` cover the
# `Components::Map` -> `ClusteredCollection.new(...)` path with
# observation-shaped objects; this file exercises the per-object
# branches in `cluster_label_for`, `cluster_url_for`, and
# `mapset_title_for` that the observation path doesn't reach
# (`Location`-shaped objects + the "neither obs nor location" fallback
# + the display_name-only label fallback).
module Mappable
  class ClusteredCollectionTest < UnitTestCase
    def setup
      super
      @obs = observations(:minimal_unknown_obs)
      @loc = locations(:burbank)
      @minimal_obs = Mappable::MinimalObservation.new(
        id: @obs.id, lat: 34.0, lng: -118.0,
        location: @obs.location, location_id: @obs.location_id,
        name_id: @obs.name_id,
        text_name: @obs.name&.text_name,
        display_name: @obs.name&.display_name,
        when: @obs.when, vote_cache: @obs.vote_cache,
        thumb_image_id: @obs.thumb_image_id
      )
      @minimal_loc = Mappable::MinimalLocation.new(
        id: @loc.id, name: @loc.name,
        north: @loc.north, south: @loc.south,
        east: @loc.east, west: @loc.west
      )
    end

    # Location-only collection — exercises `mapset_title_for`'s
    # location? branch (uses `first.display_name.to_s`) and
    # `cluster_url_for`'s location? branch (emits `location_path`).
    def test_clustered_collection_of_locations
      collection = ClusteredCollection.new([@minimal_loc])
      set = collection.sets.values.first

      assert_equal(@minimal_loc.display_name.to_s, set.title,
                   "Location mapset title should be the location's " \
                   "display name (mapset_title_for location? branch)")
      assert_match(%r{\A/locations/#{@loc.id}(\?|\z)}, set.cluster_url,
                   "cluster_url_for location? branch should emit " \
                   "location_path")
      assert(collection.sets.keys.first.to_s.start_with?("l"),
             "Location singleton_key should be l-prefixed")
    end

    # Mixed observation + location — confirms both keys land in the
    # sets hash without colliding even when their numeric ids
    # overlap (the prefix disambiguates).
    def test_clustered_collection_mixes_obs_and_locations
      collection = ClusteredCollection.new([@minimal_obs, @minimal_loc])

      keys = collection.sets.keys.map(&:to_s)
      assert_includes(keys, "o#{@minimal_obs.id}")
      assert_includes(keys, "l#{@minimal_loc.id}")
    end

    # `cluster_label_for` prefers `text_name`, then falls back to
    # `display_name`. `MinimalLocation` only has `display_name`, so
    # this exercises the second branch.
    def test_cluster_label_uses_display_name_for_locations
      collection = ClusteredCollection.new([@minimal_loc])
      set = collection.sets.values.first

      assert_equal(@minimal_loc.display_name.to_s, set.cluster_name,
                   "cluster_label_for falls through to display_name " \
                   "when text_name is absent (location case)")
    end
  end
end
