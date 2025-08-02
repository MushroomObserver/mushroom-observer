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
  def observation_show_title(obs:, owner_naming: nil, user: nil)
    [
      obs_title_id(obs),
      obs_title_consensus_name_link(
        name: obs.name, owner_naming: owner_naming, user:
      )
    ].safe_join(" ")
  end

  def obs_title_id(obs)
    tag.span(obs.id || "?", class: "badge badge-outline mr-3")
  end

  # name portion of Observation title
  def obs_title_consensus_name_link(name:, user:, owner_naming: nil)
    if name.deprecated &&
       (prefer_name = name.best_preferred_synonym).present?
      obs_title_with_preferred_synonym_link(name, prefer_name, user)
    else
      obs_title_name_link(name, owner_naming, user)
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
        name.user_display_name_brief_authors(user).t,
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

  def obs_title_name_link(name, owner_naming, user)
    text = [
      if user
        link_to_display_name_brief_authors(
          user, name, class: "obs_consensus_naming_link_#{name.id}"
        )
      else
        name.user_display_name_brief_authors(user).t
      end
    ]
    # Differentiate this Name from Observer Preference
    text << obs_consensus_id_flag if owner_naming
    text.safe_join(" ")
  end

  def obs_consensus_id_flag
    tag.span("(#{:show_observation_site_id.t})", class: "smaller")
  end

  ##### Portion of page title that includes user's naming preference #########

  # Observer Preference: Hydnum repandum
  def owner_naming_line(owner_name, current_user = User.current)
    return unless current_user&.view_owner_id

    [
      "#{:show_observation_owner_id.t}:",
      owner_favorite_or_explanation(current_user, owner_name).t
    ].safe_join(" ")
  end

  def owner_favorite_or_explanation(current_user, owner_name)
    if owner_name
      link_to_display_name_brief_authors(
        current_user, owner_name,
        class: "obs_owner_naming_link_#{owner_name.id}"
      )
    else
      :show_observation_no_clear_preference
    end
  end

  def link_to_display_name_brief_authors(user, name, **)
    link_to(name.user_display_name_brief_authors(user).t,
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

  def observation_show_image_links(obs:)
    return "" unless check_permission(obs)

    icon_link_with_query(*reuse_images_for_observation_tab(obs))
  end

  # The following sections of the observation_details partial are also needed as
  # part of the lightbox caption, so that was called on the obs_index as a
  # sub-partial. Here they're converted to helpers to speed up loading of index
  def observation_details_when_where_who(obs:, user:)
    [
      observation_details_when(obs:),
      observation_details_where(obs:, user:),
      observation_details_where_gps(obs:, user:),
      observation_details_who(obs:, user:)
    ].safe_join
  end

  def observation_details_when(obs:)
    tag.p(class: "obs-when", id: "observation_when") do
      ["#{:WHEN.t}:", tag.b(obs.when.web_date)].safe_join(" ")
    end
  end

  def observation_details_where(obs:, user:)
    tag.p(class: "obs-where", id: "observation_where") do
      [
        "#{if obs.is_collection_location
             :show_observation_collection_location.t
           else
             :show_observation_seen_at.t
           end}:",
        if user
          location_link(obs.where, obs.location, nil, true)
        else
          obs.where
        end,
        observation_where_vague_notice(obs:, user:)
      ].safe_join(" ")
    end
  end

  def observation_where_vague_notice(obs:, user:)
    return "" unless obs.location&.vague?

    title = :show_observation_vague_location.l
    title += " #{:show_observation_improve_location.l}" if user == obs.user
    tag.p(class: "ml-3") { tag.em(title) }
  end

  def observation_details_where_gps(obs:, user:)
    return "" unless obs.lat && user

    gps_display_link = link_to([obs.display_lat_lng.t,
                                obs.display_alt.t,
                                "[#{:click_for_map.t}]"].safe_join(" "),
                               map_observation_path(id: obs.id))
    gps_hidden_msg = tag.i("(#{:show_observation_gps_hidden.t})")

    tag.p(class: "obs-where-gps", id: "observation_where_gps") do
      # XXX Consider dropping this from indexes.
      concat(gps_display_link) if obs.reveal_location?(user)
      concat(gps_hidden_msg) if obs.gps_hidden
    end
  end

  def observation_details_who(obs:, user:)
    obs_user = obs.user
    html = [
      "#{:WHO.t}:",
      if user
        user_link(obs_user)
      else
        obs_user.unique_text_name
      end
    ]
    if user && obs_user != user && !obs_user&.no_emails &&
       obs_user&.email_general_question

      html += [
        "[",
        modal_link_to("observation_email", *send_observer_question_tab(obs)),
        "]"
      ]
    end

    tag.p(class: "obs-who", id: "observation_who") do
      html.safe_join(" ")
    end
  end

  def observation_details_notes(obs:)
    notes = obs.notes
    return "" if notes == Observation.no_notes
    return "#{:NOTES.t}:\n#{notes[:Other]}".tpl if notes.keys == [:Other]

    # This used to use
    #
    # notes = obs.notes_show_preformatted.sub(/^/, "#{:NOTES.t}:\n").tpl
    #
    # However, this fails if one of the values has a '+' sign, e.g., "+photo"
    # because the textile interpretation ends up affecting multiple lines.
    # This approach passes each note independently to textile.
    tag.div(class: "obs-notes textile", id: "observation_notes") do
      Textile.clear_textile_cache
      Textile.register_name(obs.name)
      concat("<p>#{:NOTES.t}:<br>".t)
      notes.each_with_object(+"") do |(key, value), _str|
        concat("+#{key}+: #{value}<br>".tl)
      end
      concat("</p>".t)
    end
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
