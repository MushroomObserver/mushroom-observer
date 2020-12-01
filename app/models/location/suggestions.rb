# frozen_string_literal: true

class Location < AbstractModel
  # Return some locations that are close to the given name and/or geolocation
  # data from google and/or lat/long provided by user.
  def self.suggestions(str, geolocation)
    return suggestions_based_on_geolocation(geolocation) if str.blank?
    return suggestions_for_country(str, geolocation) if dubious_country?(str)
    return suggestions_for_state(str, geolocation) if dubious_state?(str)

    suggestions_for_the_rest(str)
  end

  private

  # Return suggested locations matching the geolocation data.
  def self.suggestions_based_on_geolocation(geolocation)
    return [] if geolocation.empty?
    suggestions(geolocation_to_name(geolocation)) |
      suggestions_for_latlong(geolocation[:latitude], geolocation[:longitude])
  end

  # Turn geolocation structure into an MO location name (might not exist).
  def self.geolocation_to_name(geolocation)
    geo_country = geolocation[:country]
    geo_state = geolocation[:state]
    geo_county = geolocation[:county].to_s.sub(/County$/, "Co.")
    geo_city = geolocation[:city]
    [geo_city, geo_county, geo_state, geo_country].reject(&:blank?).join(", ")
  end

  # Return most specific locations containing the given lat/long.
  def self.suggestions_for_latlong(latitude, longitude)
    all = Location.where("(? BETWEEN south AND north) AND " \
                         "IF(east > west, ? BETWEEN west AND east, " \
                         "? < west OR ? > east)",
                         latitude, longitude, longitude, longitude).to_a
    # Return only most specific locations.
    (3..0).each do |n|
      locs = all.select { |loc| loc.name.split(",").length > n }
      return locs if locs.any?
    end
    []
  end

  # Return suggested locations if country is unrecognized.
  def self.suggestions_for_country(str, geolocation)
    terms = str.split(",").map(&:strip)
    given_country = terms[-1]
    geo_country = geolocation[:country]
    # Is country missing? (That is, the term in the country position is a
    # recognized state of some country.)
    if (alt_countries = countries_with_state(given_country)).any?
      terms.push("")
    # Did google provide the name of a country we recognize?
    elsif understood_country?(geo_country)
      alt_countries = [geolocation]
    # Find closest matches to the names the user and google provided.
    else
      alt_countries = similar_countries(given_country) |
                      similar_countries(geo_country)
    end
    alt_countries.map do |alt_country|
      terms[-1] = alt_country
      suggestions(terms.join(", "), geolocation)
    end.flatten.uniq
  end

  # Return suggested locations if state is unrecognized (but country is).
  def self.suggestions_for_state(str, geolocation)
    terms = str.split(",").map(&:strip)
    given_country = terms.pop
    good_states = understood_states(given_country)
    return suggestions_with_tail(str, [given_country]) if good_states.empty?

    given_state = unabbreviate_state(terms.pop, given_country)
    geo_state = geolocation[:state]
    if good_states.member?(given_state)
      alt_states = [given_state]
    elsif good_states.member?(geo_state)
      alt_states = [geo_state]
    else
      alt_states = similar_states(given_state, given_country) |
                   similar_states(geo_state, given_country)
    end
    alt_states.map do |alt_state|
      suggestions_with_tail(terms, [alt_state, given_country])
    end.flatten.uniq
  end

  # Return suggested locations if both country and state recognized.
  def self.suggestions_for_the_rest(str)
    head_terms = str.split(",").map(&:strip)
    given_country = head_terms.pop
    given_state = head_terms.pop
    tail_terms = [given_state, given_country]
    suggestions_with_tail(head_terms, tail_terms) |
      suggestions_with_county(head_terms, tail_terms) |
      suggestions_without_county(head_terms, tail_terms)
  end

  # Return locations which match except have county added.
  def self.suggestions_with_county(head_terms, tail_terms)
    return [] if head_terms.empty? || tail_terms.last != "USA" ||
                 head_terms.last.match?(/ Co(\.|unty)$/)

    head = head_terms.join(", ")
    tail = tail_terms.join(", ")
    Location.where("name LIKE ?", "#{head}, % Co., #{tail}")
  end

  # Return locations which are close except lack county.
  def self.suggestions_without_county(head_terms, tail_terms)
    return [] if head_terms.length < 2 ||
                 !head_terms.last.match?(/ Co(\.|unty)$/)

    suggestions_with_tail(head_terms[0..-2], tail_terms)
  end

  # Return locations which match at the end and are close near the front.
  def self.suggestions_with_tail(head_terms, tail_terms)
    head = head_terms.join(", ")
    tail = tail_terms.join(", ")
    return Location.where(name: tail) if head.blank?

    str = "#{head}, #{tail}"
    r = (head.length * 0.10).to_i + 1
    min = str.length - r
    max = str.length + r
    Location.where("name LIKE ? AND LENGTH(name) BETWEEN ? AND ?",
                   "%, #{tail}", min, max).
             select { |loc| Levenshtein.distance(str, loc.name) <= r }
  end

  # ----------------------------
  #  Helpers
  # ----------------------------

  def self.similar_countries(str)
    return [] if str.blank?

    understood_countries.select { |x| Levenshtein.distance(str, x) <= 2 }
  end

  def self.similar_states(str, given_country)
    return [] if str.blank?

    understood_states(given_country).select do |x|
      Levenshtein.distance(str, x) <= 2
    end
  end

  def self.countries_with_state(str)
    str = STATE_ABBREVIATIONS[str] || str
    understood_countries.select { |c| understood_states(c)&.member?(str) }
  end

  def self.dubious_state?(name)
    given_country = country(name) || return
    given_state = state(name) || return
    if has_known_states?(given_country)
      understood_state?(given_state, given_country)
    else
      state_in_database?(given_state, given_country)
    end
  end

  def self.state_in_database?(given_state, given_country)
    part_name = "#{given_state}, #{given_country}"
    Location.where("name = ? OR name LIKE ?", part_name, "%, #{part_name}").any?
  end
end
