# encoding: utf-8
#
#  = CountryCounter
#
#  This class counts how many observations are from each country
#
################################################################################

class CountryCounter
  attr_accessor :known_by_count
  attr_accessor :unknown_by_count
  attr_accessor :missing

  def initialize
    @counts = {}
    @known_by_count, @unknown_by_count = partition_with_count
    @missing = (UNDERSTOOD_COUNTRIES - Set.new(@counts.keys)).sort
  end

  private

  def partition_with_count
    countries_by_count.partition { |p| UNDERSTOOD_COUNTRIES.member?(p[0]) }
  end

  def countries_by_count
    countries.each { |c| count(c) }
    @counts.sort_by { |k, v| [-v, k] }
  end

  def countries
    (wheres + location_names).map { |l| l.split(", ")[-1] }
  end

  def wheres
    location_lookup(
      "SELECT `where` FROM observations WHERE location_id IS NULL"
    )
  end

  def location_names
    location_lookup(
      "SELECT `where` FROM observations WHERE location_id IS NOT NULL"
    )
  end

  def location_lookup(sql)
    Location.connection.select_values(sql).to_a
  end

  def self.load_param_hash(file)
    File.open(file, "r:utf-8") do |fh|
      YAML.load(fh)
    end
  end

  UNDERSTOOD_COUNTRIES = Set.new(load_param_hash(MO.location_countries_file))

  def count(country)
    @counts[country] = @counts[country] ? @counts[country] + 1 : 1
  end
end
