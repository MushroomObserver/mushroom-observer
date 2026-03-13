# frozen_string_literal: true

require "test_helper"
require "autocomplete"

class AutocompleteForRegionTest < UnitTestCase
  def create_location(name:, north:, south:, east:, west:)
    Location.create!(
      name: name,
      north: north,
      south: south,
      east: east,
      west: west,
      user: users(:rolf)
    )
  end

  def test_initialize_sets_reverse_flag
    auto_standard = Autocomplete::ForRegion.new(string: "Cal")
    assert_equal(
      false, auto_standard.reverse,
      "reverse should be false without scientific format"
    )

    auto_scientific = Autocomplete::ForRegion.new(
      string: "Cal",
      format: "scientific"
    )
    assert_equal(
      true, auto_scientific.reverse,
      "reverse should be true with scientific format"
    )
  end

  def test_rough_matches_filters_and_orders_and_uniquifies
    # Bigger area first for duplicate name
    bolivia_big = create_location(
      name: "Bolivia",
      north: 20, south: -20, east: 20, west: -20
    )
    create_location(
      name: "Bolivia", north: 1, south: -1, east: 1, west: -1
    ) # duplicate smaller
    create_location(
      name: "Dordogne, Nouvelle-Aquitaine, France", north: 10, south: 0,
      east: 10, west: 0
    )
    create_location(
      name: "Perigord, Dordogne, Nouvelle-Aquitaine, France", north: 15,
      south: -5, east: 15, west: -5
    )
    create_location(
      name: "Neighborhood, City, County, State, USA", north: 5, south: 4,
      east: 5, west: 4
    ) # 4 commas, exclude

    auto = Autocomplete::ForRegion.new(string: "Dor")
    # Letter 'D' to match word beginnings 'Dordogne'
    # and internal ' Dordogne'
    results = auto.rough_matches("D")
    names = results.pluck(:name)

    assert_includes(
      names, "Dordogne, Nouvelle-Aquitaine, France"
    )
    assert_includes(
      names, "Perigord, Dordogne, Nouvelle-Aquitaine, France"
    )
    assert_not_includes(
      names, "Neighborhood, City, County, State, USA"
    )

    # With letter 'B' only one unique Bolivia despite duplicate record
    results_b = auto.rough_matches("B")
    bolivia_results = results_b.select { |r| r[:name] == "Bolivia" }
    assert_equal(
      1, bolivia_results.size,
      "Duplicate Bolivia entries should be uniquified by name"
    )
    assert_equal(
      bolivia_big.id, bolivia_results.first[:id],
      "Returned Bolivia should be the larger box_area instance"
    )
  end

  def test_exact_match_success_and_reverse_formatting
    loc = create_location(
      name: "California, USA",
      north: 10, south: 5, east: 10, west: 5
    )
    auto_standard = Autocomplete::ForRegion.new(string: loc.name)
    result_standard = auto_standard.exact_match(loc.name)
    assert_equal([loc.name], result_standard.pluck(:name))

    auto_scientific = Autocomplete::ForRegion.new(
      string: loc.name, format: "scientific"
    )
    result_scientific = auto_scientific.exact_match(loc.name)
    assert_equal(
      ["USA, California"], result_scientific.pluck(:name),
      "Name should be reversed in scientific format"
    )
  end

  def test_exact_match_not_found
    auto = Autocomplete::ForRegion.new(string: "NoPlace")
    assert_equal([], auto.exact_match("NoPlace"))
  end

  def test_exact_match_excludes_name_with_too_many_commas
    name = "Neighborhood, City, County, State, USA" # 4 commas
    create_location(
      name: name,
      north: 10, south: 9, east: 10, west: 9
    )
    auto = Autocomplete::ForRegion.new(string: name)
    assert_equal(
      [], auto.exact_match(name),
      "Should exclude locations with more than 3 commas"
    )
  end
end
