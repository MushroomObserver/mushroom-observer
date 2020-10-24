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
    expect = Herbarium.where("name LIKE '%Herbarium'").map(&:id).sort
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
    expect = Location.where("name LIKE '%California, USA'").map(&:id).sort
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
    expect = Project.where("title LIKE 'two%'").map(&:id).sort
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
    expect = SpeciesList.where("title LIKE 'query%'").map(&:id).sort
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
    x.vals = ["2010-9"]
    assert_equal(%w[2010-09-01 2010-09-31], x.parse_date_range)
    x.vals = ["2010-9-5"]
    assert_equal(%w[2010-09-05 2010-09-05], x.parse_date_range)
    x.vals = ["2010-09-05"]
    assert_equal(%w[2010-09-05 2010-09-05], x.parse_date_range)
    x.vals = ["2010-2012"]
    assert_equal(%w[2010-01-01 2012-12-31], x.parse_date_range)
    x.vals = ["2010-3-2010-5"]
    assert_equal(%w[2010-03-01 2010-05-31], x.parse_date_range)
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
    today = Time.zone.parse("2020-09-03")
    ActiveSupport::TimeZone.any_instance.stubs(:today).returns(today)
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
    assert_equal([:Genus], x.parse_rank_range)
    x.vals = ["PHYLUM"]
    assert_equal([:Phylum], x.parse_rank_range)
    x.vals = ["dIvIsIoN"]
    assert_equal([:Phylum], x.parse_rank_range)
    x.vals = ["Group"]
    assert_equal([:Group], x.parse_rank_range)
    x.vals = ["cLADe"]
    assert_equal([:Group], x.parse_rank_range)
    x.vals = ["compleX"]
    assert_equal([:Group], x.parse_rank_range)
    x.vals = ["order-genus"]
    assert_equal([:Order, :Genus], x.parse_rank_range)
    x.vals = ["GENUS-ORDER"]
    assert_equal([:Genus, :Order], x.parse_rank_range)
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
    TranslationString.translations(:fr)[:search_term_user] = "utilisateur"
    I18n.locale = "fr"
    x = PatternSearch::Observation.new("")
    assert_equal([:users, :parse_list_of_users], x.lookup_param(:user))
    assert_equal([:users, :parse_list_of_users], x.lookup_param(:utilisateur))
  end

  def test_observation_search
    x = PatternSearch::Observation.new("Amanita")
    assert_obj_list_equal([], x.query.results)

    x = PatternSearch::Observation.new("Agaricus")
    assert_obj_list_equal(
      [observations(:agaricus_campestris_obs),
       observations(:agaricus_campestrus_obs),
       observations(:agaricus_campestras_obs),
       observations(:agaricus_campestros_obs)],
      x.query.results, :sort
    )

    x = PatternSearch::Observation.new("Agaricus user:dick")
    assert_obj_list_equal([], x.query.results)
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
    assert_obj_list_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus user:dick specimen:yes")
    assert_obj_list_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus user:dick specimen:no")
    assert_obj_list_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:2013")
    assert_obj_list_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:1")
    assert_obj_list_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:12-01")
    assert_obj_list_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus burbank date:2007-03")
    assert_obj_list_equal([observations(:agaricus_campestris_obs)],
                          x.query.results)
    x = PatternSearch::Observation.new("Agaricus albion")
    assert_obj_list_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014"
    )
    assert_obj_list_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014 specimen:true"
    )
    assert_obj_list_equal([o1], x.query.results)
  end

  def test_observation_search_date
    expect = Observation.where("YEAR(`when`) = 2006")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("date:2006")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_created
    expect = Observation.where("YEAR(created_at) = 2010")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("created:2010")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_modified
    expect = Observation.where("YEAR(updated_at) = 2013")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("modified:2013")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_name
    expect = Observation.where(name: names(:conocybe_filaris)) +
             Observation.where(name: names(:boletus_edulis))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new(
      'name:"Conocybe filaris","Boletus edulis Bull."'
    )
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_synonyms
    expect = Observation.where(name: names(:peltigera))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("Petigera include_synonyms:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_subtaxa
    names = Name.where("text_name LIKE 'Agaricus%'")
    expect = Observation.where("name_id IN (#{names.map(&:id).join(",")})")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("Agaricus include_subtaxa:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_all_name_proposals
    name = names(:agaricus_campestris)
    consensus = Observation.where(name: name)
    expect = Observation.joins(:namings).where(namings: { name: name })
    assert(consensus.count < expect.count)
    x = PatternSearch::Observation.new("Agaricus campestris" \
                                       " include_all_name_proposals:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_location
    expect = Observation.where(location: locations(:burbank))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('location:"USA, California, Burbank"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_project
    expect = projects(:bolete_project).observations
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('project:"Bolete Project"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_project_lists
    expect = projects(:bolete_project).species_lists.
             map(&:observations).flatten
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('project_lists:"Bolete Project"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_list
    expect = species_lists(:unknown_species_list).observations
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('list:"List of mysteries"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_notes
    expect = Observation.where("notes LIKE '%somewhere else%'")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new('notes:"somewhere else"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_comments
    expect = Comment.where("summary LIKE '%complicated%'").map(&:target)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("comments:complicated")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_confidence
    expect = Observation.where(vote_cache: 3)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("confidence:90")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_gps
    expect = Observation.where(lat: 34.1622, long: -118.3521)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.2 south:34.1"
    )
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_images_no
    expect = Observation.where("thumb_image_id IS NULL")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("images:no")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_images_yes
    expect = Observation.where("thumb_image_id IS NOT NULL")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("images:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_specimens_no
    expect = Observation.where(specimen: false)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("specimen:no")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_specimens_yes
    expect = Observation.where(specimen: true)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("specimen:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_sequence
    expect = Sequence.all.map(&:observation).uniq
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("sequence:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_names_no
    expect = Observation.where(name: names(:fungi))
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("has_name:no")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_names_yes
    expect = Observation.where("name_id != #{names(:fungi).id}")
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("has_name:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_notes_no
    expect = Observation.where("notes = ?", Observation.no_notes_persisted)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("has_notes:no")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_notes_yes
    expect = Observation.where("notes != ?", Observation.no_notes_persisted)
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("has_notes:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_comments_yes
    expect = Comment.where(target_type: "Observation").map(&:target).uniq
    assert(expect.count.positive?)
    x = PatternSearch::Observation.new("has_comments:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_herbarium
    nybg = herbaria(:nybg_herbarium)
    expect = HerbariumRecord.where(herbarium: nybg).
             map(&:observations).flatten.uniq
    assert_not_empty(expect)
    x = PatternSearch::Observation.new(
      'herbarium:"The New York Botanical Garden"'
    )
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_region
    expect = Observation.where("`where` LIKE '%, California, USA' OR " \
                               "`where` = 'California, USA'")
    cal = locations(:california).observations.first
    assert_not_nil(cal)
    assert_includes(expect, cal)
    x = PatternSearch::Observation.new('region:"USA, California"')
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_multiple_regions
    expect = Observation.where("`where` LIKE '%California, USA' OR " \
                               "`where` LIKE '%New York, USA'").to_a
    assert(expect.any? { |obs| obs.where.include?("California, USA") })
    assert(expect.any? { |obs| obs.where.include?("New York, USA") })
    str = 'region:"USA, California","USA, New York"'
    x = PatternSearch::Observation.new(str)
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_lichen
    lichens = Name.where("lifeform LIKE '%lichen%'")
    expect = Observation.where(name: lichens)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:yes")
    assert_obj_list_equal(expect, x.query.results, :sort)

    lichens = Name.where("lifeform LIKE '% lichen %'")
    expect = Observation.where.not(name: lichens)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:false")
    assert_obj_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_created
    expect = Name.where("YEAR(created_at) = 2010", correct_spelling: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("created:2010")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_modified
    expect = Name.where("YEAR(updated_at) = 2007", correct_spelling: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("modified:2007")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_rank
    expect = Name.with_rank(:Genus).where(correct_spelling: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:genus")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where("`rank` > #{Name.ranks[:Genus]} AND " \
                        "`rank` != #{Name.ranks[:Group]}").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:family-domain")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_synonyms
    expect = names(:macrolepiota_rachodes).synonyms.
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Macrolepiota rachodes include_synonyms:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_subtaxa
    name = names(:agaricus)
    expect = [name] + name.all_children.reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Agaricus include_subtaxa:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_synonyms
    expect = Name.where(synonym_id: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_synonyms:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where.not(synonym_id: nil).reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_synonyms:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_deprecated
    expect = Name.where(deprecated: true, correct_spelling_id: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:yes")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where(deprecated: false, correct_spelling_id: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:no")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_misspellings
    expect = Name.where.not(correct_spelling_id: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:yes")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where(correct_spelling_id: nil)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.all
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:both")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_lichen
    expect = Name.where("lifeform LIKE '%lichen%'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:yes")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where.not("lifeform LIKE '% lichen %'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:no")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_author
    expect = Name.where("COALESCE(author, '') = ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_author:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where("COALESCE(author, '') != ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_author:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_citation
    expect = Name.where("COALESCE(citation, '') = ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_citation:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where("COALESCE(citation, '') != ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_citation:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_classification
    expect = Name.where("COALESCE(classification, '') = ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_classification:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where("COALESCE(classification, '') != ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_classification:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_notes
    expect = Name.where("COALESCE(notes, '') = ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_notes:no")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where("COALESCE(notes, '') != ''").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_notes:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_comments
    expect = Comment.where(target_type: "Name").map(&:target).uniq.
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_comments:yes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_description
    expect = Name.where.not(description_id: nil).
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_description:yes")
    assert_name_list_equal(expect, x.query.results, :sort)

    expect = Name.where(description_id: nil).
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_description:no")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_author
    expect = Name.where("author LIKE '%Vittad%'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("author:vittad")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_citation
    expect = Name.where("citation LIKE '%lichenes%'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("citation:lichenes")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_classification
    expect = Name.where("classification LIKE '%ascomycota%'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("classification:Ascomycota")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_notes
    expect = Name.where("notes LIKE '%lichen%'").
             reject(&:correct_spelling_id)
    assert_not_empty(expect)
    x = PatternSearch::Name.new("notes:lichen")
    assert_name_list_equal(expect, x.query.results, :sort)
  end

  def test_name_search_comments
    expect = [comments(:fungi_comment).target]
    assert_not_empty(expect)
    x = PatternSearch::Name.new("comments:\"do not change\"")
    assert_name_list_equal(expect, x.query.results, :sort)
  end
end
