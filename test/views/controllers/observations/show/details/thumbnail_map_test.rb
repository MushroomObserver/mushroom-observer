# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Details::ThumbnailMapTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_thumbnail_map
    html = render(map_with(@obs))

    assert_html(html, "li#observation_thumbnail_map" \
                      "[data-controller='thumbnail-map']" \
                      "[data-map-url='#{routes.map_observation_path(
                        id: @obs.id
                      )}']")
    assert_html(html, "div.thumbnail-map-container" \
                      "[data-thumbnail-map-target='mapContainer']")
    assert_html(html, "div.thumbnail-map[data-thumbnail-map-target='map']")
    assert_html(html, "img#globe_image[data-thumbnail-map-target='globe']")
  end

  private

  def map_with(obs)
    Views::Controllers::Observations::Show::Details::ThumbnailMap.new(
      obs: obs
    )
  end
end
