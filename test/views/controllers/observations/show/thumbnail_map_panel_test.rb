# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::ThumbnailMapPanelTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_renders_thumbnail_map_panel
    html = render(panel_with(@obs))

    assert_html(html, "#observation_thumbnail_map")
    assert_html(html, "div.thumbnail-map-container")
    assert_html(html, "div.thumbnail-map")
    assert_html(html, "img#globe_image")
  end

  def test_parity_with_location
    erb_html = render_legacy_erb(
      "thumbnail_map", obs: @obs, user: @user, consensus: nil
    )
    phlex_html = render(panel_with(@obs))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: "#observation_thumbnail_map",
                            label: "thumbnail_map with-location"
    )
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::ThumbnailMapPanel.new(
      obs: obs, user: @user
    )
  end
end
