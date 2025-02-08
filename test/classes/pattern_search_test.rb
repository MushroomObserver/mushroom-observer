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
    expect = Location.name_contains("California, USA").map(&:id).sort
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
end
