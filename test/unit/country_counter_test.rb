# encoding: utf-8
require "test_helper"

class CountryCounterTest < UnitTestCase
  def test_wheres
    cc = CountryCounter.new
    wheres = cc.send(:wheres)
    assert(wheres)
    assert(wheres.member?("Briceland, California, USA"))
  end

  def test_location_lookup
    cc = CountryCounter.new
    lookup = cc.send(:location_lookup, "SELECT 'USA' location FROM DUAL")
    assert_equal(["USA"], lookup)
  end

  def test_location_names
    cc = CountryCounter.new
    location_names = cc.send(:location_names)
    assert(location_names)
    assert(location_names.member?("Burbank, California, USA"))
  end

  def test_countries
    cc = CountryCounter.new
    countries = cc.send(:countries)
    assert(countries)
    assert(countries.member?("USA"))
  end

  def test_countries_by_count
    cc = CountryCounter.new
    countries = cc.send(:countries_by_count)
    assert(countries)
    usa = countries[0]
    assert_equal("USA", usa[0])
    assert(10 < usa[1])
  end

  def test_partition_with_count
    cc = CountryCounter.new
    known, unknown = cc.send(:partition_with_count)
    assert(known.length > 0)
    assert(unknown.length > 0)
  end

  def test_known_by_count
    assert(CountryCounter.new.known_by_count.length > 0)
  end

  def test_unknown_by_count
    assert(CountryCounter.new.unknown_by_count.length > 0)
  end

  def test_missing
    assert(CountryCounter.new.missing.length > 0)
  end
end
