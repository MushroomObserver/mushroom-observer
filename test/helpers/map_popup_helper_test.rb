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
end
