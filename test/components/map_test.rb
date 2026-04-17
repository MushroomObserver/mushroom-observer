# frozen_string_literal: true

require "test_helper"

class MapTest < ComponentTestCase
  def setup
    super
    @location = locations(:burbank)
  end

  def test_renders_map_with_default_attributes
    html = render(Components::Map.new(objects: [@location]))

    # All default attributes on one element
    assert_html(
      html,
      "#map_div[data-controller='map']" \
      "[data-map-target='mapDiv']" \
      "[data-map-type='info']" \
      "[data-editable='false']" \
      "[data-map-open='true']" \
      "[data-need-elevations-value='true']" \
      "[data-location-format]"
    )
  end

  def test_renders_map_without_controller_when_nil
    html = render(Components::Map.new(objects: [@location], controller: nil))

    assert_no_html(html, "#map_div[data-controller]")
  end

  def test_renders_map_with_custom_options
    html = render(Components::Map.new(
                    objects: [@location],
                    map_type: "location",
                    editable: true,
                    map_open: false,
                    need_elevations_value: false,
                    map_div: "custom_map"
                  ))

    assert_html(
      html,
      "#custom_map" \
      "[data-map-type='location']" \
      "[data-editable='true']" \
      "[data-map-open='false']" \
      "[data-need-elevations-value='false']"
    )
  end

  def test_renders_json_data_attributes
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    # Controls
    controls = JSON.parse(map_div["data-controls"])
    assert_includes(controls, "large_map")
    assert_includes(controls, "map_type")

    # Collection
    collection = JSON.parse(map_div["data-collection"])
    assert(collection.key?("extents"))
    assert(collection.key?("sets"))

    # Localization
    localization = JSON.parse(map_div["data-localization"])
    assert(localization.key?("nothing_to_map"))
    assert(localization.key?("observations"))
    assert(localization.key?("locations"))
  end

  def test_renders_nothing_to_map_when_no_mappable_objects
    # Empty objects
    html = render(Components::Map.new(objects: []))
    assert_html(html, "body", text: :runtime_map_nothing_to_map.t)

    # Unknown location (no coordinates)
    unknown = Location.new(name: "Earth")
    html = render(Components::Map.new(objects: [unknown]))
    assert_html(html, "body", text: :runtime_map_nothing_to_map.t)

    # Custom message
    html = render(Components::Map.new(objects: [],
                                      nothing_to_map: "Custom message"))
    assert_html(html, "body", text: "Custom message")
  end

  def test_renders_with_observation
    observation = observations(:detailed_unknown_obs)
    html = render(Components::Map.new(objects: [observation]))

    assert_html(html, "#map_div")
  end

  # ------------------------------------------------------------------
  # #4131 popup content + marker color
  # ------------------------------------------------------------------

  def test_single_observation_popup_carries_color_name_date_consensus
    # Confirmed consensus (>= 80%) → green color.
    obs = build_min_obs(lat: 34.1, lng: -118.3, vote_cache: 2.4,
                        text_name: "Agaricus campestris",
                        when: Date.new(2024, 5, 1))
    caption, color = parse_first_set(render_map_json([obs]))

    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, color,
                 "80% consensus should yield green")
    assert_includes(caption, "Agaricus campestris")
    assert_includes(caption, 'target="_blank"')
    assert_includes(caption, 'rel="noopener noreferrer"')
    assert_match(/May 1, 2024|2024-05-01/, caption)
    # Plain "Confidence: NN%" text — no pill/dot markup inside the popup;
    # the marker color on the map is the visual cue.
    assert_match(/Confidence:\s*80%/, caption)
    assert_not_includes(caption, "●")
    assert_not_includes(caption, "nowrap")
  end

  def test_multi_observation_popup_lists_recent_names_and_no_date
    obs_a = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Oldest sp.",
                          when: Date.new(2020, 1, 1))
    obs_b = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Middle sp.",
                          when: Date.new(2023, 1, 1))
    obs_c = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Newest sp.",
                          when: Date.new(2025, 1, 1))
    caption, color = parse_first_set(render_map_json([obs_a, obs_b, obs_c]))

    assert_equal(Mappable::MapSet::GROUP_COLOR, color)
    # Most recent first.
    assert(caption.index("Newest sp.") < caption.index("Middle sp."),
           "Group popup should list most recent name first")
    assert(caption.index("Middle sp.") < caption.index("Oldest sp."))
    # No consensus dot / percentage line for groups.
    assert_no_match(/\d+%/, caption,
                    "Group popup should omit consensus %")
  end

  def test_multi_observation_popup_ellipses_beyond_three
    four_obs = Array.new(4) do |i|
      build_min_obs(lat: 5, lng: 5, vote_cache: 3.0,
                    text_name: "Species #{i}",
                    when: Date.new(2020 + i, 1, 1))
    end
    caption, _color = parse_first_set(render_map_json(four_obs))

    assert_includes(caption, "Species 3")
    assert_includes(caption, "Species 2")
    assert_includes(caption, "Species 1")
    assert_not_includes(caption, "Species 0")
    assert_includes(caption, "…")
  end

  private

  def build_min_obs(lat:, lng:, vote_cache:, text_name: nil, when: nil)
    Mappable::MinimalObservation.new(
      id: rand(1_000_000),
      lat: lat, lng: lng,
      name_id: 1, text_name: text_name,
      when: binding.local_variable_get(:when),
      vote_cache: vote_cache
    )
  end

  def render_map_json(objects)
    html = render(Components::Map.new(objects: objects))
    doc = Nokogiri::HTML(html)
    JSON.parse(doc.at_css("#map_div")["data-collection"])
  end

  def parse_first_set(collection)
    set = collection["sets"].values.first
    [set["caption"], set["color"]]
  end
end
