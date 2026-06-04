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
    obs_title_consensus_name_link(
      name: obs.name, show_owner_naming:, user:
    )
  end

  # name portion of Observation title.
  def obs_title_consensus_name_link(name:, user:, show_owner_naming: nil)
    if name.deprecated &&
       (prefer_name = name.best_preferred_synonym).present?
      obs_title_with_preferred_synonym_link(name, prefer_name, user)
    else
      obs_title_name_link(name, show_owner_naming, user)
    end
  end

  def obs_title_with_preferred_synonym_link(name, prefer_name, user)
    if user
      [
        link_to_display_name_brief_authors(
          user, name, class: "obs_consensus_deprecated_synonym_link_#{name.id}"
        ),
        # Differentiate deprecated consensus from preferred name
        obs_consensus_id_flag,
        obs_title_preferred_synonym(user, prefer_name)
      ]
    else
      [
        name.user_display_name_brief_authors(user).t.small_author,
        # Differentiate deprecated consensus from preferred name
        obs_consensus_id_flag,
        prefer_name.user_display_name_without_authors(user).t
      ]
    end.safe_join(" ")
  end

  def obs_title_preferred_synonym(user, prefer_name)
    tag.span(class: "smaller") do
      [
        "(",
        link_to_display_name_without_authors(
          user, prefer_name,
          class: "obs_preferred_synonym_link_#{prefer_name.id}"
        ),
        ")"
      ].safe_join
    end
  end

  def obs_title_name_link(name, show_owner_naming, user)
    text = [
      if user
        link_to_display_name_brief_authors(
          user, name, class: "obs_consensus_naming_link_#{name.id}"
        )
      else
        name.user_display_name_brief_authors(user).t.small_author
      end
    ]
    # Differentiate this Name from observer's preferred by printing "(Site ID)"
    text << obs_consensus_id_flag if show_owner_naming
    text.safe_join(" ")
  end

  def obs_consensus_id_flag
    tag.span("(#{:show_observation_site_id.t})", class: "small text-nowrap")
  end

  ##### Portion of page title that includes user's naming preference #########

  # Hydnum repandum (Observer Preference)
  def owner_naming_line(name:, owner_name:, user:)
    return unless user&.view_owner_id && owner_name && owner_name.id != name.id

    [
      owner_preferred_naming(user, owner_name).t,
      "(#{:show_observation_owner_id.l})"
    ].safe_join(" ")
  end

  # Note that this is called with `.t` above
  def owner_preferred_naming(user, owner_name)
    link_to_display_name_brief_authors(
      user, owner_name, class: "obs_owner_naming_link_#{owner_name.id}"
    )
  end

  # Called by more than one method
  def link_to_display_name_brief_authors(user, name, **)
    link_to(name.user_display_name_brief_authors(user).t.small_author,
            name_path(id: name.id), **)
  end

  def link_to_display_name_without_authors(user, name, **)
    link_to(name.user_display_name_without_authors(user).t,
            name_path(id: name.id), **)
  end

  def observation_map_coordinates(obs:)
    if obs.location
      loc = obs.location
      n = ((90.0 - loc.north) / 1.80).round(4)
      s = ((90.0 - loc.south) / 1.80).round(4)
      e = ((180.0 + loc.east) / 3.60).round(4)
      w = ((180.0 + loc.west) / 3.60).round(4)
    end

    lat, long = if obs.lat && obs.lng
                  [obs.public_lat, obs.public_lng]
                elsif obs.location
                  obs.location.center
                end
    if lat && long
      x = ((180.0 + long) / 3.60).round(4)
      y = ((90.0 - lat) / 1.80).round(4)
    end

    [n, s, e, w, lat, long, x, y]
  end

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
