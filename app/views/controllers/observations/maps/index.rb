# frozen_string_literal: true

# Action template for `Observations::MapsController#index` — the
# "map of observations matching a query" page. Replaces the inline
# `<div id="map_cap_banner">` + `make_map(...)` call that used to live
# in `index.html.erb`; the cap-banner is now baked into
# `Components::Map`, so the view just sets chrome and instantiates
# the component.
module Views::Controllers::Observations::Maps
  class Index < Views::Base
    prop :query, ::Query::Observations
    prop :observations, _Array(::Mappable::MinimalObservation)
    prop :observations_capped, _Boolean, default: false
    prop :observations_loaded_count, _Nilable(Integer), default: nil
    prop :observations_total_count, _Nilable(Integer), default: nil
    prop :cluster_query_string, _Nilable(String), default: nil

    def view_template
      container_class(:full)
      add_index_title(@query, map: true)
      add_context_nav(
        ::Tab::Observation::MapsActions.new(
          query: @query, controller: controller
        )
      )

      # Pass only the observations. CollapsibleCollectionOfObjects#init_sets
      # turns obs-with-GPS into a point and obs-without-GPS into a box
      # built from the obs's .location, so the locations are already
      # implicitly represented. Unioning @locations in addition produced
      # duplicate box overlays on top of obs points (#4131 follow-up).
      render(::Components::Map.new(
               objects: @observations,
               clustering: true,
               capped: @observations_capped,
               observations_loaded_count: @observations_loaded_count,
               observations_total_count: @observations_total_count,
               cluster_query_string: @cluster_query_string,
               zoom: 2,
               map_type: "info"
             ))
    end
  end
end
