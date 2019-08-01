# frozen_string_literal: true

require "test_helper"

# test methods used to count Observations by country
class CountryCounterTest < UnitTestCase
  def test_wheres
    cc = CountryCounter.new
    wheres = cc.send(:wheres)
    assert(wheres)
    assert(wheres.member?("Briceland, California, USA"))
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
    assert(usa[1] > 10)
  end

  def test_partition_with_count
    cc = CountryCounter.new
    known, unknown = cc.send(:partition_with_count)
    assert(known.present?)
    assert(unknown.present?)
  end

  def test_known_by_count
    assert(CountryCounter.new.known_by_count.present?)
  end

  def test_unknown_by_count
    assert(CountryCounter.new.unknown_by_count.present?)
  end

  def test_missing
    assert(CountryCounter.new.missing.present?)
  end
end
