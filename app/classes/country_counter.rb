# encoding: utf-8
#
#  = CountryCounter
#
#  This class counts how many observations are from each country
#
#  == Methods
#
#  num_genera::      Number of genera seen.
#  num_species::     Number of species seen.
#  genera::          List of genera (text_name) seen.
#  species::         List of species (text_name) seen.
#
#  == Usage
#
#    data = Checklist::ForUser.new(user)
#    puts "Life List: #{data.num_species} species in #{data.num_genera} genera."
#
################################################################################

class CountryCounter

  def initialize
    @counts = {}
    @known_by_count, @unknown_by_count = partition_with_count
    @missing = (UNDERSTOOD_COUNTRIES - Set.new(@counts.keys)).sort
  end
  
  def partition_with_count
    countries_by_count.partition {|p| UNDERSTOOD_COUNTRIES.member?(p[0])}
  end

  def countries_by_count
    countries.each {|c| count(c)}
    @counts.sort_by {|k,v| [-v,k]}
  end

  def countries
    (wheres+location_names).map {|l| l.split(', ')[-1]}
  end
  
  def wheres
    location_lookup("SELECT `where` location FROM observations WHERE `where` IS NOT NULL")
  end
  
  def location_lookup(sql)
    Location.connection.select_all(sql).map {|h| h['location']}
  end

  def location_names
    location_lookup("SELECT l.name location FROM observations o, locations l WHERE o.location_id = l.id AND o.`where` IS NULL")
  end

  def self.load_param_hash(file)
    File.open(file, 'r:utf-8') do |fh|
      YAML::load(fh)
    end
  end
  
  UNDERSTOOD_COUNTRIES = Set.new(load_param_hash(LOCATION_COUNTRIES_FILE))

  def known_by_count; @known_by_count; end
  def unknown_by_count; @unknown_by_count; end
  def missing; @missing; end
    
  private

  def count(country)
    @counts[country] = @counts[country] ? @counts[country]+1 : 1
  end

end
