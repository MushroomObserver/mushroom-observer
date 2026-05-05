# frozen_string_literal: true

# Info-window popup markup for map markers. Extracted from MapHelper
# to keep that module under Metrics/ModuleLength. Included back into
# MapHelper so every method stays available to map partials/components
# as before.
module MapPopupHelper
  MAX_GROUP_NAMES = 3

  def mapset_info_window(set, args)
    observations = set.observations
    if observations.length == 1 && observations.first&.id
      mapset_single_observation_popup(observations.first, set, args)
    else
      mapset_group_popup(set, args)
    end
  end

  def mapset_single_observation_popup(obs, set, args)
    tag.div(class: "media map-popup map-popup-single") do
      concat(mapset_thumbnail_media_left(obs, args))
      concat(mapset_single_observation_body(obs, set, args))
    end
  end

  def mapset_thumbnail_media_left(obs, args)
    return safe_join([]) unless obs.respond_to?(:thumb_image_id) &&
                                obs.thumb_image_id

    q = args[:query_param] ? { q: args[:query_param] } : {}
    url = observation_path(id: obs.id, params: q)
    tag.div(class: "media-left") do
      link_to(url, target: "_blank", rel: "noopener noreferrer") do
        # Empty alt: the adjacent taxon-name link inside the same
        # .media already provides the accessible label, so the
        # thumbnail is decorative in this context.
        image_tag(Image.url(:small, obs.thumb_image_id),
                  class: "media-object map-popup-thumb",
                  loading: "lazy",
                  alt: "")
      end
    end
  end

  def mapset_single_observation_body(obs, set, args)
    tag.div(class: "media-body") do
      concat(tag.div(mapset_observation_link(obs, args),
                     class: "media-heading"))
      concat(mapset_single_observation_meta(obs))
      concat(mapset_single_observation_location(set, args))
      concat(tag.div(mapset_coords(set), class: "small text-muted"))
    end
  end

  def mapset_single_observation_meta(obs)
    result = safe_join([])
    date = mapset_observation_date(obs)
    result += tag.div(date, class: "small") if date
    conf = mapset_consensus_indicator(obs)
    result += tag.div(conf, class: "small") if conf
    result
  end

  def mapset_single_observation_location(set, args)
    locations = set.underlying_locations
    return safe_join([]) unless locations.length == 1 && locations.first&.id

    tag.div(mapset_location_link(locations.first, args), class: "small")
  end

  def mapset_group_popup(set, args)
    lines = mapset_group_popup_lines(set, args)
    tag.div(lines.safe_join(safe_br), class: "map-popup map-popup-group")
  end

  def mapset_group_popup_lines(set, args)
    observations = set.observations
    lines = []
    lines << mapset_observation_header(set) if observations.length > 1
    lines.concat(mapset_group_name_links(observations, args))
    lines.concat(mapset_group_location_lines(set, args))
    lines << mapset_coords(set)
    lines
  end

  def mapset_group_location_lines(set, args)
    locations = set.underlying_locations
    return [mapset_location_header(set)] if locations.length > 1
    if locations.length == 1 && locations.first&.id
      return [mapset_location_link(locations.first, args)]
    end

    []
  end

  def mapset_group_name_links(observations, args)
    sorted = observations.sort_by { |o| [o.when || Date.new(0), o.id] }.reverse
    top = sorted.first(MAX_GROUP_NAMES)
    links = top.map { |o| mapset_observation_link(o, args) }
    links << tag.span("…") if sorted.length > MAX_GROUP_NAMES
    links
  end

  def mapset_observation_date(obs)
    return nil if obs.respond_to?(:when) && obs.when.blank?
    return nil unless obs.respond_to?(:when)

    obs.when.web_date
  end

  # Plain-text "Confidence: NN%" line. The marker color already conveys
  # the semantic bucket, so no dot/pill is needed inside the popup.
  #
  # Use `.floor` so the displayed percentage never crosses a
  # traffic-light threshold the underlying value hasn't crossed yet
  # — e.g. 79.6% should show "79%" with an orange marker, never
  # "80%" (which would look like the green/confirmed bucket).
  def mapset_consensus_indicator(obs)
    return nil unless obs.respond_to?(:vote_cache)

    pct = ::Vote.percent(obs.vote_cache)
    "#{:Confidence.t}: #{pct.floor}%"
  end

  def mapset_observation_header(set)
    show, map = mapset_associated_links(set, :observation)
    tag.div(
      map_point_text(:Observations.t, set.observations.length, show, map),
      class: "map-popup-header"
    )
  end

  def mapset_location_header(set)
    show, map = mapset_associated_links(set, :location)
    tag.div(
      map_point_text(:Locations.t, set.underlying_locations.length, show, map),
      class: "map-popup-header"
    )
  end

  # Count-first phrasing: "2 Observations [Show All] [Map All]".
  def map_point_text(label, count, show, map)
    count_label = safe_join([count.to_s, label], " ")
    safe_join([count_label, show, map], " ")
  end

  # Links to obs, locs or names within the current mapset, or maps of these
  def mapset_associated_links(set, type)
    return unless [:observation, :location, :name].include?(type)

    mapset_associated_links_for_type(set, type)
  end

  def mapset_associated_links_for_type(set, type)
    path_helper = :"#{type.to_s.pluralize}_path"
    query = mapset_links_query(set, type)
    [mapset_link(:show_all, send(path_helper), query),
     mapset_link(:map_all, send(:"map_#{path_helper}"), query)]
  end

  def mapset_links_query(set, type)
    query_type = type.to_s.camelize.to_sym
    controller.find_or_create_query(query_type,
                                    in_box: mapset_box_params(set))
  end

  def mapset_link(label_sym, path, query)
    link_to(label_sym.t, add_q_param(path, query),
            class: "btn btn-default btn-xs map-popup-btn",
            data: query.params)
  end

  def mapset_observation_link(obs, args)
    params = args[:query_param] ? { q: args[:query_param] } : {}
    label = mapset_observation_label(obs)
    link_to(label, observation_path(id: obs.id, params: params),
            target: "_blank", rel: "noopener noreferrer")
  end

  # Preferred order: display_name (has MO textile markers) → text_name
  # (wrap in <em>) → "Observation #<id>".
  def mapset_observation_label(obs)
    display = mapset_display_name(obs)
    return display.to_s.t if display.present?

    text = obs.respond_to?(:text_name) ? obs.text_name : nil
    return tag.em(text.to_s) if text.present?

    "#{:Observation.t} ##{obs.id}"
  end

  def mapset_display_name(obs)
    if obs.respond_to?(:display_name) && obs.display_name.present?
      return obs.display_name
    end
    return unless obs.respond_to?(:name) &&
                  obs.name.respond_to?(:display_name)

    obs.name.display_name
  end

  def mapset_location_link(loc, args)
    params = args[:query_param] ? { q: args[:query_param] } : {}
    link_to(loc.display_name.t, location_path(id: loc.id, params: params))
  end

  # These are query params for the links back to MO indexes, slightly enlarged
  def mapset_box_params(set)
    { north: tweak_up(set.north, 0.001, 90),
      south: tweak_down(set.south, 0.001, -90),
      east: tweak_up(set.east, 0.001, 180),
      west: tweak_down(set.west, 0.001, -180) }
  end

  def tweak_up(value, amount, max)
    [max, value.to_f + amount].min
  end

  def tweak_down(value, amount, min)
    [min, value.to_f - amount].max
  end

  # These are coords printed in text
  def mapset_coords(set)
    return mapset_point_coords(set) if set.is_point

    mapset_box_coords(set)
  end

  def mapset_point_coords(set)
    format_latitude(set.lat) + safe_nbsp + format_longitude(set.lng)
  end

  def mapset_box_coords(set)
    content_tag(:center, mapset_box_coords_inner(set))
  end

  def mapset_box_coords_inner(set)
    format_latitude(set.north) + safe_br +
      format_longitude(set.west) + safe_nbsp +
      format_longitude(set.east) + safe_br +
      format_latitude(set.south)
  end

  def format_latitude(val)
    format_lxxxitude(val, "N", "S")
  end

  def format_longitude(val)
    format_lxxxitude(val, "E", "W")
  end

  def format_lxxxitude(val, dir1, dir2)
    deg = val.abs.round(4)
    dir = val.negative? ? dir2 : dir1
    safe_join(["#{deg}°#{dir}"])
  end
end
