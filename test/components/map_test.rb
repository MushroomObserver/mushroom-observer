# frozen_string_literal: true

require "test_helper"

class MapTest < ComponentTestCase
  def setup
    super
    @location = locations(:burbank)
    # Group-popup Show All / Map All buttons call
    # `controller.find_or_create_query(...)` to mint a saved-query id.
    # The ComponentTestCase controller disables sessions, so we stub
    # it to call `Query.lookup_and_save` directly, which creates a real
    # Query record without touching the session.
    controller.define_singleton_method(:find_or_create_query) do |model, **kw|
      Query.lookup_and_save(model, kw)
    end
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
                        observed_on: Date.new(2024, 5, 1))
    caption, color = parse_first_set(render_map_json([obs]))

    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, color,
                 "80% consensus should yield green")
    assert_includes(caption, "Agaricus campestris")
    assert_includes(caption, 'target="_blank"')
    assert_includes(caption, 'rel="noopener noreferrer"')
    caption_text = Nokogiri::HTML(caption).text
    assert_match(/May 1, 2024|2024-05-01/, caption_text)
    # Plain "Confidence: NN%" text — no pill/dot markup inside the popup;
    # the marker color on the map is the visual cue.
    assert_match(/Confidence:\s*80%/, caption_text)
    assert_not_includes(caption, "●")
    assert_not_includes(caption, "nowrap")
  end

  # When the obs has neither `display_name` nor `text_name`, the
  # popup falls back to "Observation #<id>" in the link label. Pinned
  # so the label-emission chain (`render_observation_label`) keeps
  # the id-fallback branch alive (#4131 follow-up).
  def test_single_observation_popup_label_falls_back_to_id
    obs = build_min_obs(lat: 5, lng: 5, vote_cache: 3.0,
                        text_name: "",
                        observed_on: Date.new(2024, 1, 1))
    obs.display_name = nil # both display_name and text_name blank

    caption, = parse_first_set(render_map_json([obs]))

    assert_includes(caption, "##{obs.id}",
                    "Popup label falls back to 'Observation #<id>' " \
                    "when both display_name and text_name are blank")
  end

  def test_multi_observation_popup_lists_recent_names_and_no_date
    obs_a = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Oldest sp.",
                          observed_on: Date.new(2020, 1, 1))
    obs_b = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Middle sp.",
                          observed_on: Date.new(2023, 1, 1))
    obs_c = build_min_obs(lat: 10, lng: 10, vote_cache: 3.0,
                          text_name: "Newest sp.",
                          observed_on: Date.new(2025, 1, 1))
    caption, color = parse_first_set(render_map_json([obs_a, obs_b, obs_c]))

    # All three members are confirmed (vote_cache 3.0), so the group
    # inherits the confirmed band's color (#4159).
    assert_equal(Mappable::MapSet::CONFIRMED_COLOR, color)
    # Most recent first.
    assert(caption.index("Newest sp.") < caption.index("Middle sp."),
           "Group popup should list most recent name first")
    assert(caption.index("Middle sp.") < caption.index("Oldest sp."))
    # No consensus dot / percentage line for groups.
    assert_no_match(/\d+%/, Nokogiri::HTML(caption).text,
                    "Group popup should omit consensus %")
  end

  def test_multi_observation_popup_ellipses_beyond_three
    four_obs = Array.new(4) do |i|
      build_min_obs(lat: 5, lng: 5, vote_cache: 3.0,
                    text_name: "Species #{i}",
                    observed_on: Date.new(2020 + i, 1, 1))
    end
    caption, _color = parse_first_set(render_map_json(four_obs))

    assert_includes(caption, "Species 3")
    assert_includes(caption, "Species 2")
    assert_includes(caption, "Species 1")
    assert_not_includes(caption, "Species 0")
    assert_includes(caption, "…")
  end

  # ------------------------------------------------------------------
  # Group popup chrome: count header + Show All / Map All buttons.
  # ------------------------------------------------------------------

  def test_group_popup_emits_count_header_and_action_buttons
    obs = Array.new(2) do |i|
      build_min_obs(lat: 5, lng: 5, vote_cache: 3.0,
                    text_name: "Species #{i}",
                    observed_on: Date.new(2024, 1, i + 1))
    end
    caption, = parse_first_set(render_map_json(obs))

    assert_includes(caption, "map-popup-header")
    # "2 Observations" — count first, label after.
    assert_match(/2\s+#{Regexp.escape(:Observations.t.to_s)}/, caption)
    assert_includes(caption, "map-popup-btn")
    assert_includes(caption, :show_all.t)
    assert_includes(caption, :map_all.t)
  end

  # ------------------------------------------------------------------
  # Single-obs popup chrome: .media layout + thumbnail when present.
  # ------------------------------------------------------------------

  def test_single_observation_popup_uses_media_layout
    obs = build_min_obs(lat: 12, lng: 12, vote_cache: 2.4,
                        text_name: "Agaricus campestris",
                        observed_on: Date.new(2024, 5, 1))
    caption, = parse_first_set(render_map_json([obs]))
    frag = Nokogiri::HTML.fragment(caption)

    assert(frag.at_css(".media.map-popup-single"))
    assert(frag.at_css(".media-body .media-heading a"))
  end

  def test_single_observation_popup_with_thumbnail_emits_media_left
    obs = build_min_obs(lat: 12, lng: 12, vote_cache: 2.4,
                        text_name: "Agaricus campestris",
                        observed_on: Date.new(2024, 5, 1),
                        thumb_image_id: 42)
    caption, = parse_first_set(render_map_json([obs]))
    frag = Nokogiri::HTML.fragment(caption)

    assert(frag.at_css(".media-left img.map-popup-thumb"))
  end

  # ------------------------------------------------------------------
  # Clustering / cap-banner / zoom forwarding.
  # ------------------------------------------------------------------

  def test_clustering_under_cap_emits_clustering_data_attr
    obs = build_min_obs(lat: 1, lng: 1, vote_cache: 3.0,
                        text_name: "Sp.", observed_on: Date.new(2024, 1, 1))
    html = render(Components::Map.new(objects: [obs], clustering: true))

    assert_html(html, "#map_div[data-clustering='true']")
    doc = Nokogiri::HTML(html)
    collection = JSON.parse(doc.at_css("#map_div")["data-collection"])
    # ClusteredCollection — one MapSet per object, keyed "o<id>".
    assert(collection["sets"].keys.first.to_s.start_with?("o"))
  end

  def test_clustering_above_cap_falls_back_to_collapsible
    # Force the cap to a small number so we don't have to build 10k obs.
    original_cap = Components::Map::CLUSTER_MAX_OBJECTS
    Components::Map.send(:remove_const, :CLUSTER_MAX_OBJECTS)
    Components::Map.const_set(:CLUSTER_MAX_OBJECTS, 2)
    obs = Array.new(3) do |i|
      build_min_obs(lat: i + 1, lng: i + 1, vote_cache: 3.0,
                    text_name: "Sp #{i}",
                    observed_on: Date.new(2024, 1, i + 1))
    end
    html = render(Components::Map.new(objects: obs, clustering: true))

    assert_no_html(html, "#map_div[data-clustering]")
  ensure
    if original_cap
      Components::Map.send(:remove_const, :CLUSTER_MAX_OBJECTS)
      Components::Map.const_set(:CLUSTER_MAX_OBJECTS, original_cap)
    end
  end

  def test_capped_with_clustering_renders_visible_cap_banner
    obs = build_min_obs(lat: 1, lng: 1, vote_cache: 3.0,
                        text_name: "Sp.", observed_on: Date.new(2024, 1, 1))
    html = render(Components::Map.new(objects: [obs], clustering: true,
                                      capped: true,
                                      observations_loaded_count: 10_000,
                                      observations_total_count: 12_345))

    assert_html(html, "#map_cap_banner.alert.alert-warning")
    doc = Nokogiri::HTML(html)
    style = doc.at_css("#map_cap_banner")["style"]
    assert(style.nil? || style.exclude?("display:none"),
           "capped: true should not hide the banner")
    # `to_fs(:delimited)` puts a comma in the larger number.
    assert_includes(html, "12,345")
  end

  def test_uncapped_with_clustering_renders_hidden_cap_banner
    obs = build_min_obs(lat: 1, lng: 1, vote_cache: 3.0,
                        text_name: "Sp.", observed_on: Date.new(2024, 1, 1))
    html = render(Components::Map.new(objects: [obs], clustering: true,
                                      capped: false,
                                      observations_loaded_count: 100,
                                      observations_total_count: 100))

    assert_html(html, "#map_cap_banner[style*='display:none']")
  end

  def test_no_cap_banner_without_clustering
    obs = build_min_obs(lat: 1, lng: 1, vote_cache: 3.0,
                        text_name: "Sp.", observed_on: Date.new(2024, 1, 1))
    html = render(Components::Map.new(objects: [obs]))

    assert_no_html(html, "#map_cap_banner")
  end

  def test_zoom_forwarded_as_data_zoom
    html = render(Components::Map.new(objects: [@location], zoom: 4))

    assert_html(html, "#map_div[data-zoom='4']")
  end

  def test_cluster_query_string_forwarded_when_present
    html = render(Components::Map.new(objects: [@location],
                                      cluster_query_string: "q=ABC"))

    assert_html(html, "#map_div[data-cluster-query-string='q=ABC']")
  end

  # ------------------------------------------------------------------
  # Legend
  # ------------------------------------------------------------------

  def test_legend_renders_when_objects_include_observations
    obs = build_min_obs(lat: 1, lng: 1, vote_cache: 3.0,
                        text_name: "Sp.", observed_on: Date.new(2024, 1, 1))
    html = render(Components::Map.new(objects: [obs]))

    assert_html(html, ".map-legend")
    # Confirmed/tentative/disputed/mixed band labels.
    assert_includes(html, :map_legend_confirmed.t)
    assert_includes(html, :map_legend_tentative.t)
    assert_includes(html, :map_legend_disputed.t)
    assert_includes(html, :map_legend_mixed.t)
  end

  def test_legend_suppressed_on_location_only_map
    html = render(Components::Map.new(objects: [@location]))

    assert_no_html(html, ".map-legend")
  end

  private

  # Deterministic id counter so two `build_min_obs` calls in the same
  # test produce distinct ids without `rand` (cluster collections key
  # MapSets by `singleton_key_for(obj)` which embeds the id — a
  # collision overwrites the prior entry and the failure is hard to
  # reproduce).
  def next_min_obs_id
    @next_min_obs_id ||= 0
    @next_min_obs_id += 1
  end

  # `observed_on:` avoids `when` — a Ruby keyword that can't be used
  # as a method argument name — and maps to the model's `when:` attr.
  def build_min_obs(lat:, lng:, vote_cache:, **extras)
    Mappable::MinimalObservation.new(
      id: next_min_obs_id,
      lat: lat, lng: lng,
      name_id: 1,
      text_name: extras[:text_name],
      when: extras[:observed_on],
      vote_cache: vote_cache,
      thumb_image_id: extras[:thumb_image_id]
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
