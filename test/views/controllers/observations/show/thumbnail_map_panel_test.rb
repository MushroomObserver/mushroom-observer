# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ThumbnailMapPanelTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_thumbnail_map_panel
    html = render(panel_with(@obs))

    assert_html(html, "#observation_thumbnail_map")
    assert_html(html, "div.thumbnail-map-container")
    assert_html(html, "div.thumbnail-map")
    assert_html(html, "img#globe_image")
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::ThumbnailMapPanel.new(obs: obs)
  end
end
