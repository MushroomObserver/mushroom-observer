# frozen_string_literal: true

module Views::Controllers::Sequences
  # "Observation: <name> (id)" header used by sequence show / new /
  # edit pages.
  class ObservationTitle < Views::Base
    prop :observation, ::Observation

    def view_template
      div(class: "mt-3") do
        strong { "#{:OBSERVATION.l}:" }
        whitespace
        trusted_html(@observation.name.display_name(current_user).t)
        plain(" (#{@observation.id})")
      end
    end
  end
end
