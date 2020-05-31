# frozen_string_literal: true

class Query::SpeciesListAtLocation < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      location: Location
    )
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    where << "species_lists.location_id = '#{location.id}'"
    super
  end

  def default_order
    "name"
  end
end
