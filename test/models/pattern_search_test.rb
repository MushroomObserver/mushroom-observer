require "test_helper"

class PatternSearchTest < UnitTestCase
  def test_parse_next_term
    parser = PatternSearch::Parser.new("")
    x = 'test name:blah two:1,2,3 foo:"quote" bar:\'a\',"b" slash:\\,,"\\""'
    assert_equal([:pattern, "test"], parser.parse_next_term!(x))
    assert_equal([:name, "blah"], parser.parse_next_term!(x))
    assert_equal([:two, "1,2,3"], parser.parse_next_term!(x))
    assert_equal([:foo, '"quote"'], parser.parse_next_term!(x))
    assert_equal([:bar, '\'a\',"b"'], parser.parse_next_term!(x))
    assert_equal([:slash, '\\,,"\\""'], parser.parse_next_term!(x))
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
  end

  def test_parse_date_range
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_date_range }
    x.vals = [1, 2]
    assert_raises(PatternSearch::TooManyValuesError) { x.parse_date_range }
    x.vals = ["2010"]
    assert_equal(["2010-01-01", "2010-12-31"], x.parse_date_range)
    x.vals = ["2010-9"]
    assert_equal(["2010-09-01", "2010-09-31"], x.parse_date_range)
    x.vals = ["2010-9-5"]
    assert_equal(["2010-09-05", "2010-09-05"], x.parse_date_range)
    x.vals = ["2010-09-05"]
    assert_equal(["2010-09-05", "2010-09-05"], x.parse_date_range)
    x.vals = ["2010-2012"]
    assert_equal(["2010-01-01", "2012-12-31"], x.parse_date_range)
    x.vals = ["2010-3-2010-5"]
    assert_equal(["2010-03-01", "2010-05-31"], x.parse_date_range)
    x.vals = ["2010-3-12-2010-5-1"]
    assert_equal(["2010-03-12", "2010-05-01"], x.parse_date_range)
    x.vals = ["6"]
    assert_equal(["06-01", "06-31"], x.parse_date_range)
    x.vals = ["3-5"]
    assert_equal(["03-01", "05-31"], x.parse_date_range)
    x.vals = ["3-12-5-1"]
    assert_equal(["03-12", "05-01"], x.parse_date_range)
    x.vals = ["1-2-3-4-5-6"]
    assert_raises(PatternSearch::BadDateRangeError) { x.parse_date_range }
  end

  def test_parser
    x = PatternSearch::Parser.new(" abc ")
    assert_equal(" abc ", x.incoming_string)
    assert_equal("abc", x.clean_incoming_string)
    assert_equal(1, x.terms.length)
    assert_equal(:pattern, x.terms.first.var)
    assert_equal("abc", x.terms.first.parse_pattern)

    x = PatternSearch::Parser.new(' abc  user:dick "tack  this  on"')
    assert_equal('abc user:dick "tack this on"', x.clean_incoming_string)
    assert_equal(2, x.terms.length)
    y, z = x.terms.sort_by(&:var)
    assert_equal(:pattern, y.var)
    assert_equal('abc "tack this on"', y.parse_pattern)
    assert_equal(:user, z.var)
    assert_equal([dick.id], z.parse_list_of_users)
  end

  def test_observation_search
    x = PatternSearch::Observation.new("Amanita")
    assert_obj_list_equal([], x.query.results)

    x = PatternSearch::Observation.new("Agaricus")
    assert_obj_list_equal([
                            observations(:agaricus_campestris_obs),
                            observations(:agaricus_campestrus_obs),
                            observations(:agaricus_campestras_obs),
                            observations(:agaricus_campestros_obs)
                          ], x.query.results)

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
    assert_obj_list_equal([o1, o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus user:dick specimen:yes")
    assert_obj_list_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus user:dick specimen:no")
    assert_obj_list_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:2013")
    assert_obj_list_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:1")
    assert_obj_list_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:12-01")
    assert_obj_list_equal([o1, o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus burbank date:2007-03")
    assert_obj_list_equal([
                            observations(:agaricus_campestris_obs)
                          ], x.query.results)
    x = PatternSearch::Observation.new("Agaricus albion")
    assert_obj_list_equal([o1, o2], x.query.results)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014"
    )
    assert_obj_list_equal([o1, o2], x.query.results)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014 specimen:true"
    )
    assert_obj_list_equal([o1], x.query.results)
  end

  def test_observation_search_date
    expect = Observation.where("YEAR(`when`) = 2006")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("date:2006")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_created
    expect = Observation.where("YEAR(created_at) = 2010")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("created:2010")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_modified
    expect = Observation.where("YEAR(updated_at) = 2013")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("modified:2013")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_name
    expect = Observation.where(name: names(:conocybe_filaris)) +
             Observation.where(name: names(:boletus_edulis))
    assert(expect.count > 0)
    x = PatternSearch::Observation.new(
      'name:"Conocybe filaris","Boletus edulis Bull."'
    )
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_synonym_of
    expect = Observation.where(name: names(:peltigera))
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("synonym_of:Petigera")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_child_of
    names = Name.where("text_name LIKE 'Agaricus%'")
    expect = Observation.where("name_id IN (#{names.map(&:id).join(",")})")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("child_of:Agaricus")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_location
    expect = Observation.where(location: locations(:burbank))
    assert(expect.count > 0)
    x = PatternSearch::Observation.new('location:"USA, California, Burbank"')
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_project
    expect = projects(:bolete_project).observations
    assert(expect.count > 0)
    x = PatternSearch::Observation.new('project:"Bolete Project"')
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_list
    expect = species_lists(:unknown_species_list).observations
    assert(expect.count > 0)
    x = PatternSearch::Observation.new('list:"List of mysteries"')
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_notes
    expect = Observation.where("notes LIKE '%somewhere else%'")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new('notes:"somewhere else"')
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_comments
    expect = Comment.where("summary LIKE '%complicated%'").map(&:target)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("comments:complicated")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_confidence
    expect = Observation.where(vote_cache: 3)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("confidence:90")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_gps
    expect = Observation.where(lat: 34.1622, long: -118.3521)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.2 south:34.1"
    )
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_images_no
    expect = Observation.where("thumb_image_id IS NULL")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("images:no")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_images_yes
    expect = Observation.where("thumb_image_id IS NOT NULL")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("images:yes")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_specimens_no
    expect = Observation.where(specimen: false)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("specimen:no")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_specimens_yes
    expect = Observation.where(specimen: true)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("specimen:yes")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_has_names_no
    expect = Observation.where(name: names(:fungi))
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("has_name:no")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_has_names_yes
    expect = Observation.where("name_id != #{names(:fungi).id}")
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("has_name:yes")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_has_notes_no
    expect = Observation.where("notes = ?", Observation.no_notes_persisted)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("has_notes:no")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_has_notes_yes
    expect = Observation.where("notes != ?", Observation.no_notes_persisted)
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("has_notes:yes")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end

  def test_observation_search_has_comments_yes
    expect = Comment.all.map(&:target).uniq
    assert(expect.count > 0)
    x = PatternSearch::Observation.new("has_comments:yes")
    assert_obj_list_equal(expect.sort_by(&:id), x.query.results.sort_by(&:id))
  end
end
