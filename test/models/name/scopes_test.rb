# frozen_string_literal: true

require("test_helper")

# Tests for Name::Scopes (app/models/name/scopes.rb)
class Name::ScopesTest < UnitTestCase
  def test_names_matching_desired_new_parsed_name
    # Prove unauthored ParseName matches are all extant matches to text_name
    # Such as multiple authored Names
    parsed = Name.parse_name("Amanita baccata")
    expect = [names(:amanita_baccata_arora), names(:amanita_baccata_borealis)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))
    # or unauthored and authored Names
    parsed = Name.parse_name(names(:unauthored_with_naming).text_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))

    # Prove authored Group ParsedName is not matched by extant unauthored Name
    parsed = Name.parse_name("#{names(:unauthored_group).text_name} Author")
    assert_not(Name.matching_desired_new_parsed_name(parsed).
                include?(names(:unauthored_with_naming)))
    # And vice versa
    # Prove unauthored Group ParsedName is not matched by extant authored Name
    extant = names(:authored_group)
    desired = extant.text_name
    parsed = Name.parse_name(desired)
    assert_not(Name.matching_desired_new_parsed_name(parsed).include?(extant),
               "'#{desired}' unexpectedly matches '#{extant.search_name}'")

    # Prove authored non-Group ParsedName matched by union of exact matches and
    # unauthored matches
    parsed = Name.parse_name(names(:authored_with_naming).search_name)
    expect = [names(:unauthored_with_naming), names(:authored_with_naming)]
    assert_equal(expect,
                 Name.matching_desired_new_parsed_name(parsed).order(:author))
  end
  # ----------------------------------------------------
  #  Scopes
  #    Explicit tests of some scopes to improve coverage
  # ----------------------------------------------------

  def test_scope_subtaxa_of
    mispelled_name = Name.create!(
      text_name: "Amanita boodairy",
      author: "",
      search_name: "Amanita boodairy",
      display_name: "__Amanita__ __boodairy__ ",
      correct_spelling: names(:amanita_boudieri),
      deprecated: true,
      rank: "Species",
      user: users(:rolf)
    )

    amanita = names(:amanita)
    subtaxa_of_amanita = Name.subtaxa_of(amanita).order_by_default
    immediate_subtaxa_of_amanita = Name.immediate_subtaxa_of(amanita).
                                   order_by_default
    include_immediate_subtaxa = Name.include_immediate_subtaxa_of(amanita).
                                order_by_default

    # Immediate subtaxa of a genus should include everything below the genus.
    assert_equal(subtaxa_of_amanita.map(&:id),
                 immediate_subtaxa_of_amanita.map(&:id))
    assert_equal([amanita.id] + subtaxa_of_amanita.map(&:id),
                 include_immediate_subtaxa.map(&:id))

    assert_includes(
      subtaxa_of_amanita, names(:amanita_subgenus_lepidella),
      "`subtaxa_of` a genus should include subgenera"
    )
    assert_includes(
      subtaxa_of_amanita, names(:amanita_boudieri),
      "`subtaxa_of` a genus should include species"
    )
    assert_includes(
      subtaxa_of_amanita, names(:amanita_boudieri_var_beillei),
      "`subtaxa_of` a genus should include variety"
    )
    assert_includes(
      Name.subtaxa_of(names(:amanita_boudieri)),
      names(:amanita_boudieri_var_beillei),
      "`subtaxa_of` a species should include variety"
    )
    assert_includes(
      Name.subtaxa_of(names(:pluteus)),
      names(:pluteus_petasatus_deprecated),
      "`subtaxa_of` should include deprecated, but correctly spelled, names"
    )
    assert_includes(
      Name.subtaxa_of(names(:boletus)),
      names(:boletus_edulis_group),
      "`subtaxa_of` a genus should include species groups"
    )
    assert_includes(
      Name.subtaxa_of(names(:agaricales)),
      names(:agaricaceae),
      "`subtaxa_of` a class should include family whose classification" \
      "includes that class"
    )
    # This is a counter-intuitive compromise for an edge case.
    # See comments in test_scope_subtaxa_of_genus_or_below
    assert_includes(
      Name.subtaxa_of(names(:boletus_edulis)),
      names(:boletus_edulis_group),
      "`subtaxa_of` <name> should include <name> group"
    )

    # -----------------

    assert_not_includes(
      subtaxa_of_amanita, names(:amanita),
      "`subtaxa_of` a genus should not include that genus"
    )
    assert_not_includes(
      subtaxa_of_amanita, names(:boletus_edulis),
      "`subtaxa_of` a genus should not species from other genera"
    )
    assert_not_includes(
      subtaxa_of_amanita, mispelled_name,
      "`subtaxa_of` should not include misspellings"
    )

    # Above-genus: immediate_subtaxa_of returns the next rank down, not all
    # descendants. One assertion per new intermediate rank.
    assert_includes(
      Name.immediate_subtaxa_of(names(:basidiomycota)),
      names(:agaricomycotina),
      "`immediate_subtaxa_of` a Phylum should return Subphylum subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:basidiomycetes)),
      names(:agaricomycetidae),
      "`immediate_subtaxa_of` a Class should return Subclass subtaxa"
    )
    immediate_subtaxa_of_agaricales =
      Name.immediate_subtaxa_of(names(:agaricales))
    assert_includes(
      immediate_subtaxa_of_agaricales, names(:agaricineae),
      "`immediate_subtaxa_of` an Order should return Suborder subtaxa"
    )
    assert_not_includes(
      immediate_subtaxa_of_agaricales, names(:amanita),
      "`immediate_subtaxa_of` an Order should not include Genus-ranked names"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agaricaceae)),
      names(:agaricioideae),
      "`immediate_subtaxa_of` a Family should return Subfamily subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agaricioideae)),
      names(:agariceae),
      "`immediate_subtaxa_of` a Subfamily should return Tribe subtaxa"
    )
    assert_includes(
      Name.immediate_subtaxa_of(names(:agariceae)),
      names(:agaricinae),
      "`immediate_subtaxa_of` a Tribe should return Subtribe subtaxa"
    )
  end

  def test_scope_names_for_subtaxa_of_genus_or_below
    amanita_group = Name.create!(
      text_name: "Amanita group",
      search_name: "Amanita group",
      display_name: "__Amanita__ group",
      correct_spelling: nil,
      deprecated: false,
      rank: "Group",
      user: users(:rolf)
    )
    amanita_sensu_lato = Name.create!(
      text_name: "Amanita",
      author: "sensu lato",
      search_name: "Amanita sensu lato",
      display_name: "__Amanita__ sensu lato",
      correct_spelling: nil,
      deprecated: false,
      rank: "Genus",
      user: users(:rolf)
    )

    # Since lookup now does pattern matching when include_subtaxa is
    # true rather than precise name matching, "Amanita group" is now
    # included when you select "include_subtaxa".
    assert_includes(
      Name.names(lookup: "Amanita", include_subtaxa: true), amanita_group,
      "`include_subtaxa` at or below genus <X> should include `<X> group`"
    )
    # However, the semantics of exclude_original_names has now changed
    # to exclude the any of the pattern matching names.
    assert_not_includes(
      Name.names(
        lookup: "Amanita", include_subtaxa: true, exclude_original_names: true
      ), amanita_group,
      "`include_subtaxa` and `exclude_original_names` should not include " \
      "`<X> group`"
    )

    assert_not_includes(
      Name.names(
        lookup: "Amanita", include_subtaxa: true, exclude_original_names: true
      ), amanita_sensu_lato,
      "`include_subtaxa` at or below genus <X> should not include " \
      "`<X> sensu lato`"
    )
  end

  # Currently Query ignores false, so scope does too.
  # def test_scope_has_comments_false
  #   assert_includes(Name.has_comments(false), names(:bugs_bunny_one))
  #   assert_not_includes(Name.has_comments(false), names(:fungi))
  # end

  def test_scope_comments_has
    assert_includes(Name.comments_has("do not change"), names(:fungi))
    assert_empty(Name.comments_has(ARBITRARY_SHA))
    assert_empty(
      Name.comments_has(comments(:detailed_unknown_obs_comment).summary)
    )
  end

  def test_scope_classification_has_includes_genus
    # Classification column doesn't include Genus, but scientifically it should.
    # Searching for "Coprinus" should find species in that genus.
    coprinus = names(:coprinus)
    coprinus_comatus = names(:coprinus_comatus)

    results = Name.classification_has("Coprinus")

    assert_includes(results, coprinus,
                    "Should find genus itself")
    assert_includes(results, coprinus_comatus,
                    "Should find species within the genus")
  end

  def test_scope_classification_has_with_species_name
    # Searching for a binomial like "Amanita boudieri" should find the species
    # and its infraspecifics, but NOT other Amanita species.
    amanita_boudieri = names(:amanita_boudieri)
    amanita_boudieri_var = names(:amanita_boudieri_var_beillei)
    amanita_baccata = names(:amanita_baccata_arora)

    results = Name.classification_has("Amanita boudieri")

    assert_includes(results, amanita_boudieri,
                    "Should find Amanita boudieri")
    assert_includes(results, amanita_boudieri_var,
                    "Should find Amanita boudieri var. beillei")
    assert_not_includes(results, amanita_baccata,
                        "Should NOT find other Amanita species like baccata")
  end

  def test_scope_species_lists
    assert_includes(
      Name.species_lists(species_lists(:unknown_species_list)), names(:fungi)
    )
    assert_empty(Name.species_lists(species_lists(:first_species_list)))
  end

  def test_scope_within_locations
    # Have to do this, otherwise columns not populated
    Location.update_box_area_and_center_columns

    assert_includes(
      Name.within_locations(locations(:burbank)), # called with Location
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:burbank).id), # called with id
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:burbank).name), # called with string
      names(:agaricus_campestris)
    )
    assert_includes(
      Name.within_locations(locations(:california).name), # region
      names(:agaricus_campestris)
    )
    assert_not_includes(
      Name.within_locations(locations(:obs_default_location)),
      names(:notification_but_no_observation)
    )
    assert_empty(
      Name.within_locations({}),
      "Name.at_location should be empty if called with bad argument class"
    )
  end

  def test_scope_in_box
    cal = locations(:california)
    names_in_cal_box = Name.in_box(**cal.bounding_box)
    # Grab a couple of Names that are unused in Observation fixtures
    names_without_observations =
      Name.where.not(id: Name.joins(:observations)).distinct.limit(2).to_a
    obs_on_cal_border =
      Observation.create!(name: names_without_observations.first,
                          location: nil,
                          lat: cal.north,
                          lng: cal.east,
                          user: rolf)
    # Use a large location (box_area > threshold) so coordinates aren't cached
    obs_in_cal_without_lat_lng =
      Observation.create!(name: names_without_observations.second,
                          location: locations(:california),
                          lat: nil,
                          lng: nil,
                          user: rolf)

    assert_includes(names_in_cal_box, obs_on_cal_border.name)
    assert_not_includes(
      names_in_cal_box,
      obs_in_cal_without_lat_lng.name,
      "Name.in_box should exclude Names whose Observations have " \
      "large locations (box_area > threshold) with no GPS coordinates"
    )
    e = MO.box_epsilon
    box = { north: e, south: 0, east: e, west: 0 }
    assert_empty(Name.in_box(**box))
  end

  # `show_includes` (used by NamesController#show/#edit/#update and
  # Names::VersionsController#show) deliberately omits `.namings`/
  # `.observations` — eager-loading either is expensive for a name
  # with many thousands of them (e.g. a genus), and none of those
  # actions reads them directly. `merge_includes` (used only by
  # `perform_merge_names`) still needs both. `strict_loading` means
  # a wrong scope fails loudly here rather than silently N+1-ing in
  # production.
  def test_show_includes_omits_namings_and_observations
    name = Name.show_includes.find(names(:coprinus_comatus).id)

    assert_raises(ActiveRecord::StrictLoadingViolationError) do
      name.namings.to_a
    end
    assert_raises(ActiveRecord::StrictLoadingViolationError) do
      name.observations.to_a
    end
  end

  def test_merge_includes_preloads_namings_and_observations
    name = Name.merge_includes.find(names(:coprinus_comatus).id)

    assert_nothing_raised { name.namings.to_a }
    assert_nothing_raised { name.observations.to_a }
  end
end
