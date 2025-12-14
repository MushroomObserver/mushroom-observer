
# frozen_string_literal: true

require("test_helper")

class PatternSearchTest < UnitTestCase
  def test_parse_next_term
    parser = PatternSearch::Parser.new("")
    # make str mutable because it is modified by parse_next_term
    str = + 'test name:blah two:1,2,3 foo:"quote" bar:\'a\',"b" slash:\\,,"\\""'
    assert_equal([:pattern, ["test"]], parser.parse_next_term!(str))
    assert_equal([:name, ["blah"]], parser.parse_next_term!(str))
    assert_equal([:two, %w[1 2 3]], parser.parse_next_term!(str))
    assert_equal([:foo, ['"quote"']], parser.parse_next_term!(str))
    assert_equal([:bar, ["'a'", '"b"']], parser.parse_next_term!(str))
    assert_equal([:slash, ['\\,', '"\\""']], parser.parse_next_term!(str))
  end

  def test_parse_pattern_order
    parser = PatternSearch::Parser.new("")
    # make str mutable because it is modified by parse_next_term
    str = + "one two user:me three"
    assert_equal([:pattern, ["one"]], parser.parse_next_term!(str, nil))
    assert_equal([:pattern, ["two"]], parser.parse_next_term!(str, :pattern))
    assert_equal([:user, ["me"]], parser.parse_next_term!(str, :pattern))
    assert_raises(PatternSearch::PatternMustBeFirstError) \
      { parser.parse_next_term!(str, :user) }
  end

  def test_term
    x = PatternSearch::Term.new(:xxx)
    x << 2
    x << "one,\"a b c\",two"
    x << "\"1,2,3\""
    x << true
    assert_equal(:xxx, x.var)
    assert_equal(["2", "one", "a b c", "two", "1,2,3", "true"], x.vals)
  end

  def test_quote
    x = PatternSearch::Term.new(:xxx)
    assert_equal("1", x.quote(1))
    assert_equal("1", x.dequote(1))
    assert_equal("\"a b c\"", x.quote("a b c"))
    assert_equal("a b c", x.dequote("\"a b c\""))
    assert_equal("\"\\'\"", x.quote("'"))
    assert_equal("'", x.dequote("\"\\'\""))
    assert_equal("'", x.dequote("\"'\""))
    assert_equal("'", x.dequote("'''"))
    assert_equal("'", x.dequote("\\'"))
    assert_equal("'", x.dequote("'"))
    assert_equal("\" \"", x.quote(" "))
    assert_equal(" ", x.dequote("\" \""))
    assert_equal(" ", x.dequote("' '"))
    assert_equal(" ", x.dequote("\\ "))
    assert_equal("\"a b\\'c\\\"d\\\\e\"", x.quote("a b'c\"d\\e"))
    assert_equal("a b'c\"d\\e", x.dequote("\"a b\\'c\\\"d\\\\e\""))
  end

  def test_parse_pattern
    x = PatternSearch::Term.new(:xxx)
    assert_raises(PatternSearch::MissingValueError) { x.parse_pattern }
    x << "one"
    x << "two three"
    assert_equal("one \"two three\"", x.parse_pattern)
  end

  def test_parse_string
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_string }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_string }
    x.vals = ["blah"]
    assert_equal("blah", x.parse_string)
  end

  def test_parse_boolean
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_boolean }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_boolean }
    x.vals = ["0"]
    assert_equal(false, x.parse_boolean)
    x.vals = ["1"]
    assert_equal(true, x.parse_boolean)
    x.vals = ["no"]
    assert_equal(false, x.parse_boolean)
    x.vals = ["yes"]
    assert_equal(true, x.parse_boolean)
    x.vals = ["false"]
    assert_equal(false, x.parse_boolean)
    x.vals = ["true"]
    assert_equal(true, x.parse_boolean)
    x.vals = ["FALSE"]
    assert_equal(false, x.parse_boolean)
    x.vals = ["TRUE"]
    assert_equal(true, x.parse_boolean)
    x.vals = ["xxx"]
    assert_raises(PatternSearch::BadBooleanError) { x.parse_boolean }
    x.vals = ["no"]
    assert_raises(PatternSearch::BadYesError) { x.parse_boolean(:only_yes) }
  end

  def test_parse_no_include_only
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_no_include_only }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_no_include_only }
    x.vals = ["blah"]
    assert_raises(PatternSearch::BadYesNoBothError) { x.parse_no_include_only }
    x.vals = ["yes"]
    assert_equal("only", x.parse_no_include_only)
    x.vals = ["TRUE"]
    assert_equal("only", x.parse_no_include_only)
    x.vals = ["1"]
    assert_equal("only", x.parse_no_include_only)
    x.vals = ["NO"]
    assert_equal("no", x.parse_no_include_only)
    x.vals = ["false"]
    assert_equal("no", x.parse_no_include_only)
    x.vals = ["0"]
    assert_equal("no", x.parse_no_include_only)
    x.vals = ["include"]
    assert_equal("include", x.parse_no_include_only)
    x.vals = ["both"]
    assert_equal("include", x.parse_no_include_only)
    x.vals = ["EITHER"]
    assert_equal("include", x.parse_no_include_only)
  end

  def test_parse_float
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_float(-10, 10) }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_float(-10, 10) }
    x.vals = ["xxx"]
    assert_raises(PatternSearch::BadFloatError) { x.parse_float(-10, 10) }
    x.vals = ["-10.1"]
    assert_raises(PatternSearch::BadFloatError) { x.parse_float(-10, 10) }
    x.vals = ["10.1"]
    assert_raises(PatternSearch::BadFloatError) { x.parse_float(-10, 10) }
    x.vals = ["-10"]
    assert_equal(-10, x.parse_float(-10, 10))
    x.vals = ["10"]
    assert_equal(10, x.parse_float(-10, 10))
    x.vals = [".123"]
    assert_equal(0.123, x.parse_float(-10, 10))
    x.vals = ["-.123"]
    assert_equal(-0.123, x.parse_float(-10, 10))
    x.vals = ["1.234"]
    assert_equal(1.234, x.parse_float(-10, 10))
    x.vals = ["-1.234"]
    assert_equal(-1.234, x.parse_float(-10, 10))
  end

  def test_parse_confidence
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_confidence }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_confidence }
    x.vals = ["xxx"]
    assert_raises(PatternSearch::BadConfidenceError) { x.parse_confidence }
    x.vals = ["-100.1"]
    assert_raises(PatternSearch::BadConfidenceError) { x.parse_confidence }
    x.vals = ["100.1"]
    assert_raises(PatternSearch::BadConfidenceError) { x.parse_confidence }
    x.vals = ["-100"]
    assert_equal([-3, 3], x.parse_confidence)
    x.vals = ["100"]
    assert_equal([3, 3], x.parse_confidence)
    x.vals = ["90.0"]
    assert_equal([90 * 3000, 100 * 3000],
                 x.parse_confidence.map { |conf| (conf * 100_000).round })
    x.vals = ["-.123-.123"]
    assert_equal([-123 * 3, 123 * 3],
                 x.parse_confidence.map { |conf| (conf * 100_000).round })
    x.vals = ["1.234-2.345"]
    assert_equal([1234 * 3, 2345 * 3],
                 x.parse_confidence.map { |conf| (conf * 100_000).round })
  end

  def test_parse_list_of_names
    ids = Name.all[3..5].map(&:id)
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_list_of_names }
    x.vals = ["Coprinus comatus"]
    assert_equal([names(:coprinus_comatus).id], x.parse_list_of_names)
    x.vals = [ids.first.to_s]
    assert_equal([ids.first], x.parse_list_of_names)
    x.vals = ids.map(&:to_s)
    assert_equal(ids, x.parse_list_of_names)
  end

  def test_parse_list_of_herbaria
    ids = Herbarium.all[3..5].map(&:id)
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) do
      x.parse_list_of_herbaria
    end
    x.vals = ["Fungal Diversity Survey"]
    assert_equal([herbaria(:fundis_herbarium).id], x.parse_list_of_herbaria)
    x.vals = [ids.first.to_s]
    assert_equal([ids.first], x.parse_list_of_herbaria)
    x.vals = ids.map(&:to_s)
    assert_equal(ids, x.parse_list_of_herbaria)
    x.vals = ["*Herbarium"]
    expect = Herbarium.where(Herbarium[:name].matches("%Herbarium")).
             map(&:id).sort
    assert_operator(expect.count, :>, 1)
    assert_equal(expect, x.parse_list_of_herbaria.sort)
  end

  def test_parse_list_of_locations
    ids = Location.all[3..5].map(&:id)
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) do
      x.parse_list_of_locations
    end
    x.vals = ["USA, California, Burbank"]
    assert_equal([locations(:burbank).id], x.parse_list_of_locations)
    x.vals = ["Burbank, California, USA"]
    assert_equal([locations(:burbank).id], x.parse_list_of_locations)
    x.vals = [ids.first.to_s]
    assert_equal([ids.first], x.parse_list_of_locations)
    x.vals = ids.map(&:to_s)
    assert_equal(ids, x.parse_list_of_locations)
    x.vals = ["*California, USA"]
    expect = Location.name_has("California, USA").map(&:id).sort
    assert_operator(expect.count, :>, 1)
    assert_equal(expect, x.parse_list_of_locations.sort)
    x.vals = ["USA, California*"]
    assert_equal(expect, x.parse_list_of_locations.sort)
  end

  def test_parse_list_of_projects
    ids = Project.all[3..5].map(&:id)
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_list_of_projects }
    x.vals = ["Bolete Project"]
    assert_equal([projects(:bolete_project).id], x.parse_list_of_projects)
    x.vals = [ids.first.to_s]
    assert_equal([ids.first], x.parse_list_of_projects)
    x.vals = ids.map(&:to_s)
    assert_equal(ids, x.parse_list_of_projects)
    x.vals = ["two*"]
    expect = Project.where(Project[:title].matches("two%")).map(&:id).sort
    assert_operator(expect.count, :>, 1)
    assert_equal(expect, x.parse_list_of_projects.sort)
  end

  def test_parse_list_of_species_lists
    ids = SpeciesList.all[3..5].map(&:id)
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) do
      x.parse_list_of_species_lists
    end
    x.vals = ["List of mysteries"]
    assert_equal([species_lists(:unknown_species_list).id],
                 x.parse_list_of_species_lists)
    x.vals = [ids.first.to_s]
    assert_equal([ids.first], x.parse_list_of_species_lists)
    x.vals = ids.map(&:to_s)
    assert_equal(ids, x.parse_list_of_species_lists)
    x.vals = ["query*"]
    expect = SpeciesList.where(SpeciesList[:title].matches("query%")).
             map(&:id).sort
    assert_operator(expect.count, :>, 1)
    assert_equal(expect, x.parse_list_of_species_lists.sort)
  end

  def test_parse_list_of_users
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_list_of_users }
    x.vals = [mary.id.to_s]
    assert_equal([mary.id], x.parse_list_of_users)
    x.vals = ["katrina"]
    assert_equal([katrina.id], x.parse_list_of_users)
    x.vals = ["Tricky Dick"]
    assert_equal([dick.id], x.parse_list_of_users)
    x.vals = [rolf.id.to_s, mary.id.to_s, dick.id.to_s]
    assert_equal([rolf.id, mary.id, dick.id], x.parse_list_of_users)
    x.vals = ["me"]
    assert_raises(PatternSearch::UserMeNotLoggedInError) \
      { x.parse_list_of_users }
    User.current = mary
    x.vals = ["me"]
    assert_equal([mary.id], x.parse_list_of_users)
  end

  def test_parse_date_range
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_date_range }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_date_range }
    x.vals = ["2010"]
    assert_equal(%w[2010-01-01 2010-12-31], x.parse_date_range)
    # Thirty days hath September ....
    # Otherwise, mySQL says Mysql2::Error: Incorrect DATE value: '2020-09-31'
    x.vals = ["2010-9"]
    assert_equal(%w[2010-09-01 2010-09-30], x.parse_date_range)
    x.vals = ["2010-10"]
    assert_equal(%w[2010-10-01 2010-10-31], x.parse_date_range)
    x.vals = ["2010-9-5"]
    assert_equal(%w[2010-09-05 2010-09-05], x.parse_date_range)
    x.vals = ["2010-09-05"]
    assert_equal(%w[2010-09-05 2010-09-05], x.parse_date_range)
    x.vals = ["2010-2012"]
    assert_equal(%w[2010-01-01 2012-12-31], x.parse_date_range)
    x.vals = ["2010-3-2010-5"]
    assert_equal(%w[2010-03-01 2010-05-31], x.parse_date_range)
    x.vals = ["2010-3-2010-6"]
    assert_equal(%w[2010-03-01 2010-06-30], x.parse_date_range)
    x.vals = ["2010-3-12-2010-5-1"]
    assert_equal(%w[2010-03-12 2010-05-01], x.parse_date_range)
    x.vals = ["6"]
    assert_equal(%w[06-01 06-31], x.parse_date_range)
    x.vals = ["3-5"]
    assert_equal(%w[03-01 05-31], x.parse_date_range)
    x.vals = ["3-12-5-1"]
    assert_equal(%w[03-12 05-01], x.parse_date_range)
    x.vals = ["1-2-3-4-5-6"]
    assert_raises(PatternSearch::BadDateRangeError) { x.parse_date_range }
  end

  def test_parse_date_range_english
    travel_to(Time.zone.parse("2020-09-03"))
    x = PatternSearch::Term.new(:xxx)
    x.vals = ["today"]
    assert_equal(%w[2020-09-03 2020-09-03], x.parse_date_range)
    x.vals = ["yesterday"]
    assert_equal(%w[2020-09-02 2020-09-02], x.parse_date_range)
    x.vals = ["3 days ago-today"]
    assert_equal(%w[2020-08-31 2020-09-03], x.parse_date_range)
    x.vals = ["this week"]
    assert_equal(%w[2020-08-31 2020-09-06], x.parse_date_range)
    x.vals = ["last week"]
    assert_equal(%w[2020-08-24 2020-08-30], x.parse_date_range)
    x.vals = ["3_weeks_ago-yesterday"]
    assert_equal(%w[2020-08-10 2020-09-02], x.parse_date_range)
    x.vals = ["this_month"]
    assert_equal(%w[2020-09-01 2020-09-30], x.parse_date_range)
    x.vals = ["last month"]
    assert_equal(%w[2020-08-01 2020-08-31], x.parse_date_range)
    x.vals = ["3 months ago-2 months ago"]
    assert_equal(%w[2020-06-01 2020-07-31], x.parse_date_range)
    x.vals = ["this_year"]
    assert_equal(%w[2020-01-01 2020-12-31], x.parse_date_range)
    x.vals = ["last year"]
    assert_equal(%w[2019-01-01 2019-12-31], x.parse_date_range)
    x.vals = ["10 years ago"]
    assert_equal(%w[2010-01-01 2010-12-31], x.parse_date_range)
  end

  def test_parse_rank_range
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_rank_range }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_rank_range }
    x.vals = ["blah"]
    assert_raises(PatternSearch::BadRankRangeError) { x.parse_rank_range }
    x.vals = ["genus"]
    assert_equal(["Genus"], x.parse_rank_range)
    x.vals = ["PHYLUM"]
    assert_equal(["Phylum"], x.parse_rank_range)
    x.vals = ["dIvIsIoN"]
    assert_equal(["Phylum"], x.parse_rank_range)
    x.vals = ["Group"]
    assert_equal(["Group"], x.parse_rank_range)
    x.vals = ["cLADe"]
    assert_equal(["Group"], x.parse_rank_range)
    x.vals = ["compleX"]
    assert_equal(["Group"], x.parse_rank_range)
    x.vals = ["order-genus"]
    assert_equal(%w[Order Genus], x.parse_rank_range)
    x.vals = ["GENUS-ORDER"]
    assert_equal(%w[Genus Order], x.parse_rank_range)
  end

  def test_parser
    x = PatternSearch::Parser.new(" abc ")
    assert_equal(" abc ", x.incoming_string)
    assert_equal("abc", x.clean_incoming_string)
    assert_equal(1, x.terms.length)
    assert_equal(:pattern, x.terms.first.var)
    assert_equal("abc", x.terms.first.parse_pattern)

    x = PatternSearch::Parser.new(' abc   "tack  this  on"  user:dick  ')
    assert_equal('abc "tack this on" user:dick', x.clean_incoming_string)
    assert_equal(2, x.terms.length)
    y, z = x.terms.sort_by(&:var)
    assert_equal(:pattern, y.var)
    assert_equal('abc "tack this on"', y.parse_pattern)
    assert_equal(:user, z.var)
    assert_equal([dick.id], z.parse_list_of_users)
  end

  def test_translated_parameter_names
    # Ensure the translations are initialized
    assert_equal("user", :search_term_user.t)
    TranslationString.store_localizations(
      :fr, { search_term_user: "utilisateur" }
    )
    I18n.with_locale(:fr) do
      x = PatternSearch::Observation.new("")
      assert_equal([:by_users, :parse_list_of_users], x.lookup_param(:user))
      assert_equal([:by_users, :parse_list_of_users],
                   x.lookup_param(:utilisateur))
    end
  end

  # ----- PatternSearch::Location tests -----

  def test_location_pattern_search_params
    search = PatternSearch::Location.new("")
    params = search.params

    # Verify key parameters exist
    assert(params.key?(:region))
    assert(params.key?(:user))
    assert(params.key?(:created))
    assert(params.key?(:modified))
    assert(params.key?(:has_notes))
    assert(params.key?(:has_observations))
    assert(params.key?(:has_descriptions))
    assert(params.key?(:north))
    assert(params.key?(:south))
    assert(params.key?(:east))
    assert(params.key?(:west))
  end

  def test_location_pattern_search_model
    search = PatternSearch::Location.new("")
    assert_equal(::Location, search.model)
  end

  def test_location_pattern_search_simple
    search = PatternSearch::Location.new("burbank")
    assert_equal("burbank", search.query.params[:pattern])
  end

  def test_location_pattern_search_with_region
    search = PatternSearch::Location.new('region:"California, USA"')
    assert_equal(["California, USA"], search.query.params[:region])
  end

  def test_location_pattern_search_with_user
    dick = users(:dick)
    search = PatternSearch::Location.new("user:dick")
    assert_equal([dick.id], search.query.params[:by_users])
  end

  def test_location_pattern_search_with_notes
    search = PatternSearch::Location.new("notes:test")
    assert_equal("test", search.query.params[:notes_has])
  end

  def test_location_pattern_search_with_has_notes
    search = PatternSearch::Location.new("has_notes:yes")
    assert_equal(true, search.query.params[:has_notes])
  end

  def test_location_pattern_search_with_has_observations
    search = PatternSearch::Location.new("has_observations:yes")
    assert_equal(true, search.query.params[:has_observations])
  end

  def test_location_pattern_search_with_has_descriptions
    search = PatternSearch::Location.new("has_descriptions:yes")
    assert_equal(true, search.query.params[:has_descriptions])
  end

  def test_location_pattern_search_with_bounding_box
    search = PatternSearch::Location.new(
      "north:35 south:34 east:-118 west:-119"
    )
    assert_equal(
      { north: 35.0, south: 34.0, east: -118.0, west: -119.0 },
      search.query.params[:in_box]
    )
  end

  def test_location_pattern_search_with_swapped_north_south
    # Should auto-correct swapped north/south values
    search = PatternSearch::Location.new(
      "north:34 south:35 east:-118 west:-119"
    )
    assert_equal(
      { north: 35.0, south: 34.0, east: -118.0, west: -119.0 },
      search.query.params[:in_box]
    )
  end

  def test_location_pattern_search_with_missing_north
    search = PatternSearch::Location.new("south:34 east:-118 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::MissingValueError, search.errors.first)
    assert_equal(:north, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_missing_south
    search = PatternSearch::Location.new("north:35 east:-118 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::MissingValueError, search.errors.first)
    assert_equal(:south, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_missing_east
    search = PatternSearch::Location.new("north:35 south:34 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::MissingValueError, search.errors.first)
    assert_equal(:east, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_missing_west
    search = PatternSearch::Location.new("north:35 south:34 east:-118")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::MissingValueError, search.errors.first)
    assert_equal(:west, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_invalid_north
    # North latitude must be between -90 and 90
    search = PatternSearch::Location.new("north:95 south:34 east:-118 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::BadFloatError, search.errors.first)
    assert_equal(:north, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_invalid_south
    # South latitude must be between -90 and 90
    search = PatternSearch::Location.new("north:35 south:-95 east:-118 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::BadFloatError, search.errors.first)
    assert_equal(:south, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_invalid_east
    # East longitude must be between -180 and 180
    search = PatternSearch::Location.new("north:35 south:34 east:185 west:-119")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::BadFloatError, search.errors.first)
    assert_equal(:east, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_invalid_west
    # West longitude must be between -180 and 180
    search = PatternSearch::Location.new("north:35 south:34 east:-118 west:-185")
    assert_equal(1, search.errors.length)
    assert_instance_of(PatternSearch::BadFloatError, search.errors.first)
    assert_equal(:west, search.errors.first.args[:var])
  end

  def test_location_pattern_search_with_dates
    search = PatternSearch::Location.new("created:2021-01-01")
    assert_equal(%w[2021-01-01 2021-01-01],
                 search.query.params[:created_at])
  end

  def test_location_pattern_search_terms_help
    help_text = PatternSearch::Location.terms_help
    assert(help_text.include?("region"))
    assert(help_text.include?("user"))
    assert(help_text.include?("created"))
    assert(help_text.include?("modified"))
    assert(help_text.include?("has_notes"))
  end

  def test_location_pattern_search_combined_params
    dick = users(:dick)
    search = PatternSearch::Location.new(
      'park region:"California, USA" user:dick has_notes:yes'
    )
    assert_equal("park", search.query.params[:pattern])
    assert_equal(["California, USA"], search.query.params[:region])
    assert_equal([dick.id], search.query.params[:by_users])
    assert_equal(true, search.query.params[:has_notes])
  end
end
