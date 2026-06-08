# frozen_string_literal: true

require("test_helper")

# Coverage for `MapPopupHelper#mapset_observation_label` fallbacks
# (#4159). `display_name` is the preferred label; these tests exercise
# the `text_name` wrap branch and the final "Observation #<id>"
# fallback when neither is available.
class MapPopupHelperTest < ActionView::TestCase
  # mapset_display_name returns nil for obs without a display_name,
  # so the method falls through to the text_name branch and wraps
  # it in <em>.
  def test_mapset_observation_label_wraps_text_name_in_em
    obs = Struct.new(:id, :text_name).new(42, "Amanita muscaria")
    result = mapset_observation_label(obs)
    assert_includes(result, "<em>Amanita muscaria</em>",
                    "text_name-only obs should render as italic plain text")
  end

  # text_name is present but blank — still falls through to the
  # final "Observation #<id>" return.
  def test_mapset_observation_label_falls_back_when_text_name_blank
    obs = Struct.new(:id, :text_name).new(7, "")
    result = mapset_observation_label(obs)
    assert_match(/#7\z/, result,
                 "blank text_name should fall through to id fallback")
  end

  # Neither display_name nor text_name available — returns the
  # "Observation #<id>" string.
  def test_mapset_observation_label_final_fallback_to_id
    obs = Struct.new(:id).new(99)
    result = mapset_observation_label(obs)
    assert_match(/#99\z/, result,
                 "obs with no name fields should render as 'Observation #id'")
    assert_includes(result, :Observation.t,
                    "id-fallback label should use the :Observation locale key")
  end

  # Line 199: obs has no direct display_name but has a .name with one.
  def test_mapset_display_name_delegates_to_name_display_name
    name_obj = Struct.new(:display_name).new("Amanita muscaria")
    obs = Struct.new(:name).new(name_obj)
    assert_equal("Amanita muscaria", mapset_display_name(obs),
                 "Expected display_name from obs.name")
  end

  # Lines 30-33, 37: obs has thumb_image_id — renders the media-left
  # thumbnail wrapped in a link to the observation.
  def test_mapset_thumbnail_media_left_with_thumb_image
    obs = observations(:detailed_unknown_obs)
    args = { query_param: "abc123" }
    html = mapset_thumbnail_media_left(obs, args)
    doc = Nokogiri::HTML(html)

    expected_url = observation_path(id: obs.id, params: { q: "abc123" })
    assert(doc.at_css(".media-left"),
           "Expected media-left wrapper div")
    assert(doc.at_css("a[href='#{expected_url}']"),
           "Expected link to observation with query param")
    assert(doc.at_css("img"),
           "Expected thumbnail img tag inside the link")
  end

  # Lines 126-127: mapset_observation_header renders a .map-popup-header
  # div. mapset_associated_links is stubbed to avoid the controller
  # dependency (find_or_create_query).
  def test_mapset_observation_header_renders_header_div
    obs_list = [observations(:minimal_unknown_obs),
                observations(:detailed_unknown_obs)]
    set = Struct.new(:observations).new(obs_list)
    stub_links = ["<a>Show</a>".html_safe, "<a>Map</a>".html_safe]
    stub(:mapset_associated_links, stub_links) do
      html = mapset_observation_header(set)
      doc = Nokogiri::HTML(html)

      assert(doc.at_css(".map-popup-header"),
             "Expected map-popup-header div")
      assert(doc.at_css(".map-popup-header a"),
             "Expected links inside the header")
    end
  end
end
