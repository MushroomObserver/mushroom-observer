# frozen_string_literal: true

# Action template for `Observations::MapsController#show` — the map of
# a single observation (always one minimal observation in `@observations`).
module Views::Controllers::Observations::Maps
  class Show < Views::FullPageBase
    prop :observation, ::Observation
    prop :observations, _Array(::Mappable::MinimalObservation)
    prop :query, _Nilable(::Query), default: nil

    def view_template
      container_class(:full)
      add_page_title(:map_observation_title.t(id: @observation.id))
      add_context_nav(
        ::Tab::Observation::MapsActions.new(
          query: @query, controller: controller
        )
      )

      Map(
        objects: @observations,
        zoom: 2,
        map_type: "observation"
      )
    end
  end
end
