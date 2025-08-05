# frozen_string_literal: true

# helper methods for Location-related views:
# ListCountries, ListLocations, ShowLocation
module LocationsHelper
  def location_show_title(location)
    [
      location.display_name,
      tag.span(location.id || "?", class: "badge badge-id ml-3")
    ].safe_join(" ")
  end

  def country_link(country, count = nil)
    str = country + (count ? ": #{count}" : "")
    link_to(str, locations_path(country: country))
  end

  # title of a link to Observations at a location, with observation count
  # Observations at this Location(nn)
  def show_obs_link_title_with_count(location)
    "#{:show_location_observations.t} (#{location.observations.size})"
  end

  def calc_counts(locations, query)
    list = find_species_list(query)
    unless list
      return Observation.where(location: locations).group(:location_id).count
    end

    Observation.joins(:species_lists).
      where(location: locations, species_lists: { id: list }).
      group(:location_id).count
  end

  def find_species_list(query)
    # Make this super safe since it's not clear what query actually contains
    return nil unless query.respond_to?(:params)
    return nil unless query.params.is_a?(Hash)

    obs_query = query.params[:observation_query]
    return nil unless obs_query.is_a?(Hash)

    species_lists = obs_query[:species_lists]
    return nil unless species_lists.is_a?(Array)
    return nil unless species_lists.length == 1

    SpeciesList.safe_find(species_lists[0])
  end
end
