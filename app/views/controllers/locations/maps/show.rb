# frozen_string_literal: true

# Action template for `Locations::MapsController#show` — the map of
# all locations matching the current Location query. Replaces
# `locations/maps/show.html.erb`. No cap banner (Location queries
# bound to `MO.query_max_array` rather than the obs-style 10k cap).
module Views::Controllers::Locations::Maps
  class Show < Views::FullPageBase
    prop :query, ::Query::Locations
    prop :locations, _Array(::Mappable::MinimalLocation)

    def view_template
      container_class(:full)
      add_index_title(@query, map: true)
      add_context_nav(
        ::Tab::Location::MapActions.new(
          query: @query, controller: controller
        )
      )

      render(::Components::Map.new(
               objects: @locations,
               zoom: 2,
               map_type: "location"
             ))
    end
  end
end
