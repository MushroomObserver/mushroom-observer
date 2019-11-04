# frozen_string_literal: true

# helper methods for Location-related views:
# ListCountries, ListLocations, ShowLocation
module LocationHelper
  def country_link(country, count = nil)
    str = country + (count ? ": #{count}" : "")
    link_to(str, action: :list_by_country, country: country)
  end

  # title of a link to Observations at a location, with observation count
  # Observations at this Location(nn)
  def show_obs_link_title_with_count(location)
    "#{:show_location_observations.t} (#{location.observations.count})"
  end

  def calc_counts(locations)
    results = {}
    if locations.any?
      # Location.connection.select_rows(%(
      #   SELECT locations.id, COUNT(observations.id)
      #   FROM locations
      #   JOIN observations ON observations.location_id = locations.id
      #   WHERE locations.id IN (#{locations.map(&:id).join(",")})
      #   GROUP BY locations.id
      #     )).each do |id, count|
      Observation.where(location: locations)
        .group(:location_id).count.each do |id, count|
        results[id] = count
      end
    end
    results
  end
end
