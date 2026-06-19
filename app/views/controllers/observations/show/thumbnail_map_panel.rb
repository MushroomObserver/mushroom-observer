# frozen_string_literal: true

# "Map" panel on the observation show page. Displays a small static
# globe image with a red pin at the observation's lat/long (and a
# bounding box for the location footprint when available), all
# wired to the `thumbnail-map` Stimulus controller — the controller
# zooms / pans the image client-side. Heading link toggles the
# panel off via a user-pref endpoint.
#
# `coordinates` computes the (n, s, e, w, lat, long, x, y) tuple
# for the map marker.
class Views::Controllers::Observations::Show::ThumbnailMapPanel < Views::Base
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::ImageURL

  prop :obs, ::Observation

  def view_template
    render(Components::Panel.new(
             panel_id: "observation_thumbnail_map",
             attributes: {
               data: { controller: "thumbnail-map",
                       coordinates: { x: x, y: y }.to_json,
                       map_url: map_observation_path(id: @obs.id) }
             }
           )) do |panel|
      panel.with_heading { :MAP.t }
      panel.with_heading_links { heading_links }
      panel.with_body { render_body }
    end
  end

  private

  def heading_links
    render(Components::Link::Icon.new(
             tab: ::Tab::Observation::HideThumbnailMap.new(observation: @obs)
           ))
  end

  def render_body
    div(class: "thumbnail-map-container",
        data: { thumbnail_map_target: "mapContainer" }) do
      render_zoom_buttons
      render_map
    end
  end

  def render_zoom_buttons
    div(class: "thumbnail-buttons") do
      div(class: "plus-button",
          data: { action: "thumbnail-map#zoomTo:stop",
                  thumbnail_map_zoom_dir_param: "1" })
      div(class: "minus-button",
          data: { action: "thumbnail-map#zoomTo:stop",
                  thumbnail_map_zoom_dir_param: "-1" })
    end
  end

  def render_map
    div(class: "thumbnail-map", data: { thumbnail_map_target: "map" }) do
      render_bounding_box if @obs.location
      render_pin if lat && long
      render_globe
    end
  end

  def render_bounding_box
    bounding_rects.each { |rect| render_box(*rect) }
  end

  # 0–2 rects: empty when degenerate (s ≤ n); one rect when the
  # box fits without crossing the antimeridian; two rects (left
  # half from x=0, right half from x=w) when it does.
  def bounding_rects
    return [] unless (s - n).positive?

    w < e ? [single_box_rect] : antimeridian_box_rects
  end

  def single_box_rect
    [w, n, e - w, s - n]
  end

  def antimeridian_box_rects
    [[0, n, e, s - n], [w, n, 100 - w, s - n]]
  end

  def render_box(left, top, width, height)
    style = "left:#{left}%; top:#{top}%; " \
            "width:#{width}%; height:#{height}%"
    div(class: "thumbnail-map-box", style: style)
  end

  def render_pin
    div(class: "pin-offset") do
      div(class: "red-pin",
          style: "left:#{x}%; bottom:#{100 - y}%")
    end
  end

  def render_globe
    image_tag(
      "globe.jpg",
      class: "w-100", id: "globe_image",
      data: { globe_large_url: image_url("globe_large.jpg"),
              thumbnail_map_target: "globe" }
    )
  end

  # Pre-Phlex `ObservationsHelper#observation_map_coordinates`
  # — projects the obs's lat/long (or its location's bounding
  # box) into 0-100% screen coordinates for the static globe
  # backdrop (Mercator-ish, simple linear projection). Inlined.
  def coordinates
    @coordinates ||= compute_coordinates
  end

  def n = coordinates[0]
  def s = coordinates[1]
  def e = coordinates[2]
  def w = coordinates[3]
  def lat = coordinates[4]
  def long = coordinates[5]
  def x = coordinates[6]
  def y = coordinates[7]

  def compute_coordinates
    n, s, e, w = box_coordinates
    lat, long = pin_coordinates
    x, y = project(lat, long) if lat && long
    [n, s, e, w, lat, long, x, y]
  end

  def box_coordinates
    loc = @obs.location
    return [nil, nil, nil, nil] unless loc

    [(90.0 - loc.north) / 1.80,
     (90.0 - loc.south) / 1.80,
     (180.0 + loc.east) / 3.60,
     (180.0 + loc.west) / 3.60].map { |v| v.round(4) }
  end

  def pin_coordinates
    if @obs.lat && @obs.lng
      # `public_lat` / `public_lng` returns the obfuscated value
      # when the obs's GPS is hidden — keeps the pin away from
      # the precise location.
      [@obs.public_lat, @obs.public_lng]
    elsif @obs.location
      @obs.location.center
    else
      [nil, nil]
    end
  end

  def project(lat, long)
    [((180.0 + long) / 3.60).round(4),
     ((90.0 - lat) / 1.80).round(4)]
  end
end
