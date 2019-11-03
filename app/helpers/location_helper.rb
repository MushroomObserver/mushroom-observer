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
end
