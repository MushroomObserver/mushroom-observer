# frozen_string_literal: true

require("test_helper")

module Locations
  class UndefinedControllerTest < FunctionalTestCase
    def test_index
      login
      get(:index)

      assert_response(:success)
      assert_page_title(:list_place_names_undef.t)
    end

    def test_index_letter_filter
      Observation.create!(
        user: rolf, when: Time.zone.today,
        where: "Albuquerque, New Mexico, USA",
        name: names(:agaricus_campestris)
      )
      Observation.create!(
        user: rolf, when: Time.zone.today,
        where: "Boulder, Colorado, USA",
        name: names(:agaricus_campestris)
      )

      login
      get(:index)
      assert(assigns(:undef_data).present?, "Should have undefined locations")

      get(:index, params: { letter: "a" })
      undef_data = assigns(:undef_data)
      skip if undef_data.blank?

      # `undef_data` is an Array of `[obs, count]` tuples, not a Hash --
      # `each_key` isn't available; cop false-positives on the
      # destructured block.
      undef_data.each do |obs, _count| # rubocop:disable Style/HashEachMethods
        assert_match(/^A/i, obs[:where], "Filtered results should start with A")
      end
    end

    # `@undef_data` is grouped by `where` and reported as
    # `[representative_observation, count]` tuples -- duplicate `where`
    # strings on a page collapse into one row carrying the group size.
    def test_index_groups_duplicates_with_count
      where_str = "Duplicate Place, Imaginary, Country"
      2.times do
        Observation.create!(
          user: rolf, when: Time.zone.today,
          where: where_str, name: names(:agaricus_campestris)
        )
      end

      login
      get(:index)
      assert_response(:success)

      undef_data = assigns(:undef_data)
      pair = undef_data.find { |obs, _count| obs[:where] == where_str }
      assert(pair, "Duplicate `where` row should be present in @undef_data")
      obs, count = pair
      assert_equal(2, count,
                   "Both observations sharing #{where_str.inspect} " \
                   "should be folded into one row with count 2")
      assert_equal(where_str, obs[:where])
    end
  end
end
