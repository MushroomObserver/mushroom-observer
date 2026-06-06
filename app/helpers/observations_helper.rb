# frozen_string_literal: true

# helpers for show Observation view
module ObservationsHelper
  ##### Portion of page title that includes consensus naming (site id) #########
  #
  # Depends on whether consensus is deprecated and user preferences include
  # showing Observer's Preference
  #
  # Consensus not deprecated, observer preference not shown:
  #   Observation nnn: Aaa bbb Author(s)
  # Consensus deprecated, observer preference not shown:
  #   Observation nnn: Ccc ddd Author(s) (Site ID) (Aaa bbb)
  # Observer preference shown, consensus not deprecated:
  #   Observation nnn: Aaa bbb Author(s) (Site ID)
  #
  # NOTE: Must pass owner naming, or it will be recalculated on every obs.
  # Only used for the page <title> element. #title is composed from parts.
  def observation_show_title(obs:, show_owner_naming: nil, user: nil)
    ::Observations::ConsensusNameLink.for(
      name: obs.name, user: user, show_owner_naming: show_owner_naming
    )
  end

  # Title-builder chain extracted to `Observations::ConsensusNameLink`
  # — composes `DisplayNameBriefAuthorsLink` and
  # `DisplayNameWithoutAuthorsLink` POROs; handles deprecated /
  # owner-preferred branches. See `app/classes/observations/`.

  # `owner_naming_line` + `owner_preferred_naming` extracted to
  # `Observations::OwnerNamingLine`.

  def observation_location_help
    loc1 = "Albion, Mendocino Co., California, USA"
    loc2 = "Hotel Parque dos Coqueiros, Aracaju, Sergipe, Brazil"
    if User.current_location_format == "scientific"
      loc1 = Location.reverse_name(loc1)
      loc2 = Location.reverse_name(loc2)
    end

    [tag.div(:form_observations_where_help.t(loc1: loc1, loc2: loc2),
             class: "mb-3"),
     tag.div(:form_observations_locate_on_map_help.t)].safe_join
  end
end
