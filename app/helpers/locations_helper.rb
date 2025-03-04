# frozen_string_literal: true

# helper methods for Location-related views:
# ListCountries, ListLocations, ShowLocation
module LocationsHelper
  def country_link(country, count = nil)
    str = country + (count ? ": #{count}" : "")
    link_to(str, locations_path(country: country))
  end

  # title of a link to Observations at a location, with observation count
  # Observations at this Location(nn)
  def show_obs_link_title_with_count(location)
    "#{:show_location_observations.t} (#{location.observations.size})"
  end

  def calc_counts(locations)
    Observation.where(location: locations).group(:location_id).count
  end
end
