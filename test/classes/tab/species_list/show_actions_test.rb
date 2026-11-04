# frozen_string_literal: true

require("test_helper")

# Tests for Tab::SpeciesList::ShowActions -- the action-tab strip
# above the species-list show page's observation listing.
module Tab::SpeciesList
  class ShowActionsTest < UnitTestCase
    # unknown_species_list's two observations share both name and
    # location -- a naive row count would say 2/2, DISTINCT says 1/1.
    def test_name_and_location_counts_dedupes
      list = species_lists(:unknown_species_list)

      assert_equal([1, 1], name_and_location_counts(list))
    end

    # `location_id` is nullable (an observation can have a free-text
    # "where" with no matched Location row); `COUNT(DISTINCT ...)`
    # excludes NULLs, so observations with no location don't inflate
    # the count. one_genus_three_species_list has 4 observations with
    # 4 distinct names, only one of which has a matched location.
    def test_name_and_location_counts_excludes_null_location
      list = species_lists(:one_genus_three_species_list)

      assert_equal([4, 1], name_and_location_counts(list))
    end

    private

    def name_and_location_counts(list)
      show_actions = Tab::SpeciesList::ShowActions.new(
        species_list: list, project: nil, query: nil, controller: nil,
        observations_count: list.observations.count
      )
      show_actions.send(:name_and_location_counts)
    end
  end
end
