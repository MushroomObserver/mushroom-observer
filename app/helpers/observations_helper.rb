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
  def show_obs_title(obs:, owner_naming: nil)
    [
      obs_title_id(obs),
      obs_title_consensus_name_link(name: obs.name, owner_naming: owner_naming)
    ].safe_join(" ")
  end

  def obs_title_id(obs)
    tag.span(class: "smaller") do
      [:show_observation_header.t, tag.span("#{obs.id || "?"}:")].safe_join(" ")
    end
  end

  # name portion of Observation title
  def obs_title_consensus_name_link(name:, owner_naming: nil)
    if name.deprecated &&
       (prefer_name = name.best_preferred_synonym).present?
      obs_title_with_preferred_synonym_link(name, prefer_name)
    else
      obs_title_name_link(name, owner_naming)
    end
  end

  def obs_title_with_preferred_synonym_link(name, prefer_name)
    [
      link_to_display_name_brief_authors(
        name, class: "obs_consensus_deprecated_synonym_link_#{name.id}"
      ),
      # Differentiate deprecated consensus from preferred name
      obs_consensus_id_flag,
      obs_title_preferred_synonym(prefer_name)
    ].safe_join(" ")
  end

  def obs_title_preferred_synonym(prefer_name)
    tag.span(class: "smaller") do
      [
        "(",
        link_to_display_name_without_authors(
          prefer_name, class: "obs_preferred_synonym_link_#{prefer_name.id}"
        ),
        ")"
      ].safe_join
    end
  end

  def obs_title_name_link(name, owner_naming)
    text = [
      link_to_display_name_brief_authors(
        name, class: "obs_consensus_naming_link_#{name.id}"
      )
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
  def owner_naming_line(obs)
    return unless User.current&.view_owner_id

    [
      "#{:show_observation_owner_id.t}:",
      owner_favorite_or_explanation(obs).t
    ].safe_join(" ")
  end

  def owner_favorite_or_explanation(obs)
    if (name = obs.owner_preference)
      link_to_display_name_brief_authors(
        name, class: "obs_owner_naming_link_#{name.id}"
      )
    else
      :show_observation_no_clear_preference
    end
  end

  # N+1 - this has gotta go. We have each naming's votes already
  # def gather_users_votes(obs, user = nil)
  #   return [] unless user

  #   obs.namings.includes([:votes, :user, :name]).each_with_object({}) do
  #     |naming, votes|
  #     votes[naming.id] =
  #       naming.votes.find { |vote| vote.user_id == user.id } ||
  #       Vote.new(value: 0)
  #   end
  # end

  def link_to_display_name_brief_authors(name, **args)
    link_to(name.display_name_brief_authors.t,
            name_path(id: name.id), **args)
  end

  def link_to_display_name_without_authors(name, **args)
    link_to(name.display_name_without_authors.t,
            name_path(id: name.id), **args)
  end

  def observation_map_coordinates(obs:)
    if obs.location
      loc = obs.location
      n = ((90.0 - loc.north) / 1.80).round(6)
      s = ((90.0 - loc.south) / 1.80).round(6)
      e = ((180.0 + loc.east) / 3.60).round(6)
      w = ((180.0 + loc.west) / 3.60).round(6)
    end

    lat, long = if obs.lat && obs.long
                  [obs.public_lat, obs.public_long]
                elsif obs.location
                  obs.location.center
                end
    if lat && long
      x = ((180.0 + long) / 3.60).round(6)
      y = ((90.0 - lat) / 1.80).round(6)
    end

    [n, s, e, w, lat, long, x, y]
  end

  def observation_show_image_links(obs:)
    return "" unless check_permission(obs)

    [
      icon_link_with_query(
        :show_observation_add_images.t,
        new_image_for_observation_path(obs.id), icon: :add
      ),
      " | ",
      icon_link_with_query(
        :show_observation_reuse_image.t,
        reuse_images_for_observation_path(obs.id), icon: :reuse
      ),
      " | ",
      icon_link_with_query(
        :show_observation_remove_images.t,
        remove_images_from_observation_path(obs.id), icon: :remove
      )
    ].safe_join
  end

  # The following sections of the observation_details partial are also needed as
  # part of the lightbox caption, so that was called on the obs_index as a
  # sub-partial. Here they're converted to helpers to speed up loading of index
  def observation_details_when_where_who(obs:)
    [
      observation_details_when(obs: obs),
      observation_details_where(obs: obs),
      observation_details_where_gps(obs: obs),
      observation_details_who(obs: obs)
    ].safe_join
  end

  def observation_details_when(obs:)
    tag.p(class: "obs-when", id: "observation_when") do
      ["#{:WHEN.t}:", tag.b(obs.when.web_date)].safe_join(" ")
    end
  end

  def observation_details_where(obs:)
    tag.p(class: "obs-where", id: "observation_where") do
      [
        "#{if obs.is_collection_location
             :show_observation_collection_location.t
           else
             :show_observation_seen_at.t
           end}:",
        location_link(obs.place_name, obs.location, nil, true)
      ].safe_join(" ")
    end
  end

  def observation_details_where_gps(obs:)
    return "" unless obs.lat

    gps_display_link = link_to([obs.display_lat_long.t,
                                obs.display_alt.t,
                                "[#{:click_for_map.t}]"].safe_join(" "),
                               map_observation_path(id: obs.id))
    gps_hidden_msg = tag.i("(#{:show_observation_gps_hidden.t})")

    tag.p(class: "obs-where-gps", id: "observation_where_gps") do
      # XXX Consider dropping this from indexes.
      concat(gps_display_link) if obs.reveal_location?
      concat(gps_hidden_msg) if obs.gps_hidden
    end
  end

  def observation_details_who(obs:)
    obs_user = obs.user
    html = [
      "#{:WHO.t}:",
      user_link(obs_user)
    ]
    if obs_user != User.current && !obs_user.no_emails &&
       obs_user.email_general_question

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
    return "" unless obs.notes?

    notes = obs.notes_show_formatted.sub(/^\A/, "#{:NOTES.t}:\n").tpl

    tag.div(class: "obs-notes", id: "observation_notes") do
      Textile.clear_textile_cache
      Textile.register_name(obs.name)
      tag.div(notes)
    end
  end
end
