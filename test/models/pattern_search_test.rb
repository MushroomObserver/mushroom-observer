# encoding: utf-8

require "test_helper"
class PatternSearchTest < UnitTestCase
  def test_term
    x = PatternSearch::Term.new(:xxx)
    x << 2
    x << "xxx"
    x << true
    assert_equal(x.var, :xxx)
    assert_equal(x.vals, [2, "xxx", true])
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

  def test_parse_boolean
    x = PatternSearch::Term.new(:xxx)
    x.vals = [];        assert_raises(PatternSearch::MissingValueError) { x.parse_boolean }
    x.vals = [1, 2];    assert_raises(PatternSearch::TooManyValuesError) { x.parse_boolean }
    x.vals = ["0"];     assert_equal(false, x.parse_boolean)
    x.vals = ["1"];     assert_equal(true,  x.parse_boolean)
    x.vals = ["no"];    assert_equal(false, x.parse_boolean)
    x.vals = ["yes"];   assert_equal(true,  x.parse_boolean)
    x.vals = ["false"]; assert_equal(false, x.parse_boolean)
    x.vals = ["true"];  assert_equal(true,  x.parse_boolean)
    x.vals = ["FALSE"]; assert_equal(false, x.parse_boolean)
    x.vals = ["TRUE"];  assert_equal(true,  x.parse_boolean)
    x.vals = ["xxx"];   assert_raises(PatternSearch::BadBooleanError) { x.parse_boolean }
  end

  def test_parse_list_of_users
    x = PatternSearch::Term.new(:xxx)
    x.vals = []
    assert_raises(PatternSearch::MissingValueError) { x.parse_list_of_users }

    x.vals = [mary.id.to_s]
    assert_obj_list_equal([mary], x.parse_list_of_users)

    x.vals = ["katrina"]
    assert_obj_list_equal([katrina], x.parse_list_of_users)

    x.vals = ["Tricky Dick"]
    assert_obj_list_equal([dick], x.parse_list_of_users)

    x.vals = [rolf.id.to_s, mary.id.to_s, dick.id.to_s]
    assert_obj_list_equal([rolf, mary, dick], x.parse_list_of_users)
  end

  def test_parse_date_range
    x = PatternSearch::Term.new(:xxx)
    x.vals = []; assert_raises(PatternSearch::MissingValueError) { x.parse_date_range }
    x.vals = [1, 2]; assert_raises(PatternSearch::TooManyValuesError) { x.parse_date_range }
    x.vals = ["2010"]; assert_equal(["2010-01-01", "2010-12-31"], x.parse_date_range)
    x.vals = ["2010-9"]; assert_equal(["2010-09-01", "2010-09-31"], x.parse_date_range)
    x.vals = ["2010-9-5"]; assert_equal(["2010-09-05", "2010-09-05"], x.parse_date_range)
    x.vals = ["2010-09-05"]; assert_equal(["2010-09-05", "2010-09-05"], x.parse_date_range)
    x.vals = ["2010-2012"]; assert_equal(["2010-01-01", "2012-12-31"], x.parse_date_range)
    x.vals = ["2010-3-2010-5"]; assert_equal(["2010-03-01", "2010-05-31"], x.parse_date_range)
    x.vals = ["2010-3-12-2010-5-1"]; assert_equal(["2010-03-12", "2010-05-01"], x.parse_date_range)
    x.vals = ["6"]; assert_equal(["06-01", "06-31"], x.parse_date_range)
    x.vals = ["3-5"]; assert_equal(["03-01", "05-31"], x.parse_date_range)
    x.vals = ["3-12-5-1"]; assert_equal(["03-12", "05-01"], x.parse_date_range)
    x.vals = ["1-2-3-4-5-6"]; assert_raises(PatternSearch::BadDateRangeError) { x.parse_date_range }
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
    assert_obj_list_equal([dick], z.parse_list_of_users)
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
    o1 = Observation.create!(when: Date.parse("10/01/2012"), location: albion, name: agaricus, user: dick, specimen: true)
    o2 = Observation.create!(when: Date.parse("30/12/2013"), location: albion, name: agaricus, user: dick, specimen: false)
    assert_equal(20120110, o1.when.year * 10000 + o1.when.month * 100 + o1.when.day)
    assert_equal(20131230, o2.when.year * 10000 + o2.when.month * 100 + o2.when.day)
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
    x = PatternSearch::Observation.new("Agaricus albion user:dick date:2001-2014")
    assert_obj_list_equal([o1, o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus albion user:dick date:2001-2014 specimen:true")
    assert_obj_list_equal([o1], x.query.results)
  end
end
