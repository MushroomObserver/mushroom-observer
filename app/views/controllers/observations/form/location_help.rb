# frozen_string_literal: true

# Two-paragraph help text that appears under the location-autocompleter
# field on the observation form. Localized example locations are
# flipped between postal and scientific order based on the current
# user's `location_format`.
module Views::Controllers::Observations
  class Form::LocationHelp < Views::Base
    POSTAL_LOC1 = "Albion, Mendocino Co., California, USA"
    POSTAL_LOC2 = "Hotel Parque dos Coqueiros, Aracaju, Sergipe, Brazil"

    def view_template
      div(class: "mb-3") do
        trusted_html(:form_observations_where_help.t(loc1: loc1, loc2: loc2))
      end
      div do
        trusted_html(:form_observations_locate_on_map_help.t)
      end
    end

    private

    def loc1
      scientific? ? ::Location.reverse_name(POSTAL_LOC1) : POSTAL_LOC1
    end

    def loc2
      scientific? ? ::Location.reverse_name(POSTAL_LOC2) : POSTAL_LOC2
    end

    def scientific?
      current_user&.location_format == "scientific"
    end
  end
end
