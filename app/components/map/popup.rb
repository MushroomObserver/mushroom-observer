# frozen_string_literal: true

# Map-marker info-window popup. Rendered standalone by:
#
# - `Components::Map` — once per `Mappable::MapSet`, captured into a
#   SafeBuffer and stashed on `mapset.caption` so the client-side
#   `map_controller.js` can drop it into the marker's popup `<div>`.
# - `Observations::MapsController#popup` — for the lazy-load JSON
#   endpoint clustered maps call when a marker is clicked (#4159),
#   so a single-obs popup ships down without the bulk-render cost.
#
# The two entry points share this class so the rendered popup HTML
# is identical regardless of how it was reached.
#
# Two flavors driven by the mapset shape:
#
# - Single-observation (one obs with a real id) → Bootstrap `.media`
#   layout with a thumbnail on the left and the obs metadata
#   (name link, date, confidence, location, coords) in the body.
# - Multi-observation (group) → count header with Show All / Map All
#   buttons pointing at filtered MO indexes, plus the top
#   `MAX_GROUP_NAMES` observation name links and the box coords.
class Components::Map::Popup < Components::Base
  MAX_GROUP_NAMES = 3

  prop :set, ::Mappable::MapSet
  # The Query the user is navigating — used to mint `?q=…` on every
  # link inside the popup so a click lands inside the same filtered
  # query context. Falls back to `current_query` (controller's
  # session-current query, already validated) when omitted, so
  # callers like `Components::Map` don't have to forward it.
  prop :query, _Nilable(::Query), default: nil
  # Bbox queries for Show All / Map All group-popup buttons. Computed
  # by the caller (clustering module or controller) to keep the popup
  # a pure renderer. When nil the buttons are omitted.
  prop :observation_bbox_query,
       _Nilable(_Interface(:id, :q_param, :params)), default: nil
  prop :location_bbox_query,
       _Nilable(_Interface(:id, :q_param, :params)), default: nil

  def view_template
    if single_obs_set?
      build_single_observation_popup(@set.observations.first)
    else
      build_group_popup
    end
  end

  private

  def single_obs_set?
    @set.observations.length == 1 && @set.observations.first&.id
  end

  def effective_query
    @effective_query ||= @query || current_query
  end

  def query_path_params
    q = effective_query&.q_param
    q ? { q: q } : {}
  end

  # ----------------------------------------------------------------
  # Single-observation popup
  # ----------------------------------------------------------------

  def build_single_observation_popup(obs)
    div(class: "media map-popup map-popup-single") do
      render_thumbnail_media_left(obs)
      render_single_observation_body(obs)
    end
  end

  def render_thumbnail_media_left(obs)
    return unless obs.respond_to?(:thumb_image_id) && obs.thumb_image_id

    url = observation_path(id: obs.id, params: query_path_params)
    div(class: "media-left") do
      a(href: url, target: "_blank", rel: "noopener noreferrer") do
        # Empty alt: the adjacent taxon-name link inside the same
        # .media already provides the accessible label, so the
        # thumbnail is decorative in this context.
        img(src: ::Image.url(:small, obs.thumb_image_id),
            class: "media-object map-popup-thumb",
            loading: "lazy", alt: "")
      end
    end
  end

  def render_single_observation_body(obs)
    div(class: "media-body") do
      div(class: "media-heading") { render_observation_link(obs) }
      render_single_observation_meta(obs)
      render_single_observation_location
      div(class: "small text-muted") { render_coords }
    end
  end

  def render_single_observation_meta(obs)
    date = mapset_observation_date(obs)
    div(class: "small") { plain(date.to_s) } if date
    conf = mapset_consensus_indicator(obs)
    div(class: "small") { plain(conf) } if conf
  end

  def render_single_observation_location
    locations = @set.underlying_locations
    return unless locations.length == 1 && locations.first&.id

    div(class: "small") { render_location_link(locations.first) }
  end

  # ----------------------------------------------------------------
  # Group popup
  # ----------------------------------------------------------------

  def build_group_popup
    div(class: "map-popup map-popup-group") do
      lines = group_popup_lines
      lines.each_with_index do |emitter, idx|
        br if idx.positive?
        emitter.call
      end
    end
  end

  def group_popup_lines
    lines = []
    observations = @set.observations
    lines << -> { render_observation_header } if observations.length > 1
    group_name_links(observations).each { |link| lines << link }
    group_location_lines.each { |line| lines << line }
    lines << -> { render_coords }
    lines
  end

  def group_location_lines
    locations = @set.underlying_locations
    return [-> { render_location_header }] if locations.length > 1
    if locations.length == 1 && locations.first&.id
      return [-> { render_location_link(locations.first) }]
    end

    []
  end

  def group_name_links(observations)
    sorted = observations.sort_by { |o| [o.when || Date.new(0), o.id] }.reverse
    top = sorted.first(MAX_GROUP_NAMES)
    links = top.map { |o| -> { render_observation_link(o) } }
    links << -> { span { plain("…") } } if sorted.length > MAX_GROUP_NAMES
    links
  end

  def render_observation_header
    div(class: "map-popup-header") do
      plain("#{@set.observations.length} #{:Observations.t} ")
      render_associated_links(:observation)
    end
  end

  def render_location_header
    div(class: "map-popup-header") do
      plain("#{@set.underlying_locations.length} #{:Locations.t} ")
      render_associated_links(:location)
    end
  end

  # Show All / Map All buttons pointing at filtered MO indexes for the
  # mapset's bounding box.
  def render_associated_links(type)
    return unless [:observation, :location, :name].include?(type)

    bbox_query = if type == :observation
                   @observation_bbox_query
                 else
                   @location_bbox_query
                 end
    return unless bbox_query

    path_helper = :"#{type.to_s.pluralize}_path"
    render_mapset_link(:show_all, send(path_helper), bbox_query)
    plain(" ")
    render_mapset_link(:map_all, send(:"map_#{path_helper}"), bbox_query)
  end

  def render_mapset_link(label_sym, path, query)
    render(::Components::Button.new(
             type: :get,
             name: label_sym.t,
             target: add_q_param(path, query),
             size: :xs,
             class: "map-popup-btn",
             data: query.params
           ))
  end

  # ----------------------------------------------------------------
  # Observation / location links
  # ----------------------------------------------------------------

  def render_observation_link(obs)
    render(::Components::Link::Get.new(
             name: obs.text_name.presence || "Observation ##{obs.id}",
             target: observation_path(id: obs.id,
                                      params: query_path_params),
             new_tab: true
           )) { render_observation_label(obs) }
  end

  # Emits the label inside the observation-popup link. Preferred order:
  # display_name (has MO textile markers) → text_name (wrapped in
  # <em>) → "Observation #<id>". Emits directly into the surrounding
  # buffer — no string-returning so we never have to construct an
  # `<em>` via Rails helpers.
  def render_observation_label(obs)
    display = mapset_display_name(obs)
    if display.present?
      trusted_html(display.to_s.t)
    elsif obs.respond_to?(:text_name) && obs.text_name.present?
      em { plain(obs.text_name.to_s) }
    else
      plain("#{:Observation.t} ##{obs.id}")
    end
  end

  def mapset_display_name(obs)
    if obs.respond_to?(:display_name) && obs.display_name.present?
      return obs.display_name
    end
    return unless obs.respond_to?(:name) &&
                  obs.name.respond_to?(:display_name)

    obs.name.display_name
  end

  def render_location_link(loc)
    render(::Components::Link::Location.new(location: loc))
  end

  def mapset_observation_date(obs)
    return nil unless obs.respond_to?(:when) && obs.when.present?

    obs.when.web_date
  end

  # Plain-text "Confidence: NN%" line. The marker color already conveys
  # the semantic bucket, so no dot/pill is needed inside the popup.
  #
  # `.floor` so the displayed percentage never crosses a traffic-light
  # threshold the underlying value hasn't crossed yet — e.g. 79.6%
  # should show "79%" with an orange marker, never "80%" (which would
  # look like the green/confirmed bucket).
  def mapset_consensus_indicator(obs)
    return nil unless obs.respond_to?(:vote_cache)

    pct = ::Vote.percent(obs.vote_cache)
    "#{:Confidence.t}: #{pct.floor}%"
  end

  # ----------------------------------------------------------------
  # Coordinate formatting
  # ----------------------------------------------------------------

  def render_coords
    @set.is_point ? render_point_coords : render_box_coords
  end

  def render_point_coords
    plain(format_latitude(@set.lat))
    nbsp
    plain(format_longitude(@set.lng))
  end

  def render_box_coords
    center do
      plain(format_latitude(@set.north))
      br
      plain(format_longitude(@set.west))
      nbsp
      plain(format_longitude(@set.east))
      br
      plain(format_latitude(@set.south))
    end
  end

  def format_latitude(val)
    format_coordinate(val, "N", "S")
  end

  def format_longitude(val)
    format_coordinate(val, "E", "W")
  end

  def format_coordinate(val, positive_dir, negative_dir)
    deg = val.abs.round(4)
    "#{deg}°#{val.negative? ? negative_dir : positive_dir}"
  end

  # Phlex 2.x doesn't ship `<center>` since it's a deprecated HTML
  # element, but the Google Maps popup historically uses it to stack
  # the box-coord lines on top of each other (the popup's tiny visual
  # vocabulary). Register it so `center { ... }` emits the tag.
  register_element :center
end
