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

  def test_parse_yes_no_both
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_yes_no_both }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_yes_no_both }
    x.vals = ["blah"]
    assert_raises(PatternSearch::BadYesNoBothError) { x.parse_yes_no_both }
    x.vals = ["yes"]
    assert_equal("only", x.parse_yes_no_both)
    x.vals = ["TRUE"]
    assert_equal("only", x.parse_yes_no_both)
    x.vals = ["1"]
    assert_equal("only", x.parse_yes_no_both)
    x.vals = ["NO"]
    assert_equal("no", x.parse_yes_no_both)
    x.vals = ["false"]
    assert_equal("no", x.parse_yes_no_both)
    x.vals = ["0"]
    assert_equal("no", x.parse_yes_no_both)
    x.vals = ["both"]
    assert_equal("either", x.parse_yes_no_both)
    x.vals = ["EITHER"]
    assert_equal("either", x.parse_yes_no_both)
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
    expect = Location.name_includes("California, USA").map(&:id).sort
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
      assert_equal([:users, :parse_list_of_users], x.lookup_param(:user))
      assert_equal([:users, :parse_list_of_users], x.lookup_param(:utilisateur))
    end
  end

  def test_observation_search_name_hack
    # "Turkey" is not a name, and no taxa modifiers present, so no reason to
    # suspect that this is a name query.  Should leave it completely alone.
    x = PatternSearch::Observation.new("Turkey")
    assert_equal(:pattern_search, x.flavor)
    assert_equal({ pattern: "Turkey" }, x.args)

    # "Agaricus" is a name, so let's assume this is a name query.  Note that
    # it will include synonyms and subtaxa by default.
    x = PatternSearch::Observation.new("Agaricus")
    assert_equal(:all, x.flavor)
    assert_equal({ names: "Agaricus", include_subtaxa: true,
                   include_synonyms: true }, x.args)

    # "Turkey" is not a name, true, but user asked for synonyms to be included,
    # so they must have expected "Turkey" to be a name.  Note that it will also
    # include subtaxa by default, because that behavior was not specified.
    x = PatternSearch::Observation.new("Turkey include_synonyms:yes")
    assert_equal(:all, x.flavor)
    assert_equal({ names: "Turkey", include_synonyms: true,
                   include_subtaxa: true }, x.args)

    # Just make sure the user is allowed to explicitly turn off synonyms and
    # subtaxa in any names query.
    x = PatternSearch::Observation.new("Foo bar include_synonyms:no " \
                                       "include_subtaxa:no")
    assert_equal(:all, x.flavor)
    assert_equal({ names: "Foo bar", include_synonyms: false,
                   include_subtaxa: false }, x.args)
  end

  def test_observation_search
    x = PatternSearch::Observation.new("Amanita")
    assert_obj_arrays_equal([], x.query.results)

    x = PatternSearch::Observation.new("Agaricus")
    assert_obj_arrays_equal(
      [observations(:agaricus_campestris_obs),
       observations(:agaricus_campestrus_obs),
       observations(:agaricus_campestras_obs),
       observations(:agaricus_campestros_obs)],
      x.query.results, :sort
    )

    x = PatternSearch::Observation.new("Agaricus user:dick")
    assert_obj_arrays_equal([], x.query.results)
    albion = locations(:albion)
    agaricus = names(:agaricus)
    o1 = Observation.create!(when: Date.parse("10/01/2012"),
                             location: albion, name: agaricus, user: dick,
                             specimen: true)
    o2 = Observation.create!(when: Date.parse("30/12/2013"),
                             location: albion, name: agaricus, user: dick,
                             specimen: false)
    assert_equal(20_120_110,
                 o1.when.year * 10_000 + o1.when.month * 100 + o1.when.day)
    assert_equal(20_131_230,
                 o2.when.year * 10_000 + o2.when.month * 100 + o2.when.day)
    x = PatternSearch::Observation.new("Agaricus user:dick")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus user:dick with_specimen:yes")
    assert_obj_arrays_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus user:dick with_specimen:no")
    assert_obj_arrays_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:2013")
    assert_obj_arrays_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:1")
    assert_obj_arrays_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:12-01")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus burbank date:2007-03")
    assert_obj_arrays_equal([observations(:agaricus_campestris_obs)],
                            x.query.results)
    x = PatternSearch::Observation.new("Agaricus albion")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014"
    )
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014 with_specimen:true"
    )
    assert_obj_arrays_equal([o1], x.query.results)
  end

  def test_observation_search_date
    expect = Observation.where(Observation[:when].year == 2006)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("date:2006")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_created
    expect = Observation.where(Observation[:created_at].year == 2010)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("created:2010")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_modified
    expect = Observation.where(Observation[:updated_at].year == 2013)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("modified:2013")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_name
    expect = Observation.where(name: names(:conocybe_filaris)) +
             Observation.where(name: names(:boletus_edulis))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new(
      'name:"Conocybe filaris","Boletus edulis Bull."'
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_synonyms
    expect = Observation.where(name: [names(:peltigera), names(:petigera)])
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("Petigera include_synonyms:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_subtaxa
    expect = Observation.of_name(names(:agaricus), include_subtaxa: true)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("Agaricus include_subtaxa:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_all_name_proposals
    expect = Observation.of_name(names(:agaricus_campestris),
                                 include_all_name_proposals: true)
    consensus = Observation.where(name: name)
    assert(consensus.count < expect.count)
    x = PatternSearch::Observation.new("Agaricus campestris " \
                                       "include_all_name_proposals:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_location
    expect = Observation.where(location: locations(:burbank))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('location:"USA, California, Burbank"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_project
    expect = Observation.for_project(projects(:bolete_project))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('project:"Bolete Project"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_project_lists
    expect = Observation.on_species_list_of_project(projects(:bolete_project))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('project_lists:"Bolete Project"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_list
    expect = Observation.on_species_list(species_lists(:unknown_species_list))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('list:"List of mysteries"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_notes
    expect = Observation.notes_include("somewhere else")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('notes:"somewhere else"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_comments
    expect = Observation.comments_include("complicated")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("comments:complicated")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_confidence
    expect = Observation.where(vote_cache: 3)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("confidence:90")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_gps
    expect = Observation.where(lat: 34.1622, lng: -118.3521)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.2 south:34.1"
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_images_no
    expect = Observation.without_image
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_images:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_images_yes
    expect = Observation.with_image
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_images:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_specimens_no
    expect = Observation.without_specimen
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_specimen:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_specimens_yes
    expect = Observation.with_specimen
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_specimen:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_sequence
    expect = Observation.with_sequence
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_sequence:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_with_names_no
    expect = Observation.without_name
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_name:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_with_names_yes
    expect = Observation.with_name
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_name:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_with_notes_no
    expect = Observation.without_notes
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_notes:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_with_notes_yes
    expect = Observation.with_notes
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_notes:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_with_comments_yes
    expect = Observation.with_comments
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("with_comments:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_herbarium
    expect = Observation.in_herbarium(herbaria(:nybg_herbarium))
    assert_not_empty(expect)
    x = PatternSearch::Observation.new(
      'herbarium:"The New York Botanical Garden"'
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_region
    expect = Observation.in_region("California, USA")
    cal = locations(:california).observations.first
    assert_not_nil(cal)
    assert_includes(expect, cal)
    x = PatternSearch::Observation.new('region:"USA, California"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_multiple_regions
    expect = Observation.in_region("California, USA").
             or(Observation.in_region("New York, USA")).to_a
    assert(expect.any? { |obs| obs.where.include?("California, USA") })
    assert(expect.any? { |obs| obs.where.include?("New York, USA") })
    str = 'region:"USA, California","USA, New York"'
    x = PatternSearch::Observation.new(str)
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_lichen
    expect = Observation.where(name: Name.of_lichens)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)

    expect = Observation.where(name: Name.not_lichens)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:false")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_created
    expect = Name.with_correct_spelling.where(Name[:created_at].year == 2010)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("created:2010")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_modified
    expect = Name.with_correct_spelling.where(Name[:updated_at].year == 2007)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("modified:2007")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_rank
    expect = Name.with_correct_spelling.with_rank("Genus")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:genus")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_rank_above_genus
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:family-domain")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_synonyms
    expect = Name.include_synonyms_of(names(:macrolepiota_rachodes))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Macrolepiota rachodes include_synonyms:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_subtaxa
    expect = Name.include_subtaxa_of(names(:agaricus))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Agaricus include_subtaxa:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_synonyms
    expect = Name.without_synonyms
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_synonyms:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_synonyms.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_synonyms:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_deprecated
    expect = Name.deprecated.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.not_deprecated.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_misspellings
    expect = Name.with_incorrect_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.all
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:both")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_lichen
    expect = Name.with_correct_spelling.of_lichens
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.not_lichens
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_author
    expect = Name.with_correct_spelling.without_author
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_author:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_author
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_author:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_citation
    expect = Name.with_correct_spelling.without_citation
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_citation:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_citation
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_citation:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_classification
    expect = Name.with_correct_spelling.without_classification
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_classification:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_classification
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_classification:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_notes
    expect = Name.with_correct_spelling.without_notes
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_notes:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_notes
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_notes:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_comments
    expect = Name.with_correct_spelling.with_comments
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_comments:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_with_description
    expect = Name.with_correct_spelling.with_description
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_description:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.without_description
    assert_not_empty(expect)
    x = PatternSearch::Name.new("with_description:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_author
    expect = Name.with_correct_spelling.author_includes("Vittad")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("author:vittad")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_citation
    expect = Name.with_correct_spelling.citation_includes("lichenes")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("citation:lichenes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_classification
    expect = Name.with_correct_spelling.classification_includes("ascomycota")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("classification:Ascomycota")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_notes
    expect = Name.with_correct_spelling.notes_include("lichen")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("notes:lichen")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_comments
    expect = [comments(:fungi_comment).target]
    assert_not_empty(expect)
    x = PatternSearch::Name.new("comments:\"do not change\"")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end
end
