# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Details::ThumbnailMapTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
    @user = users(:rolf)
  end

  def test_renders_thumbnail_map
    html = render(map_with(@obs, @user))

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

  def test_renders_nothing_when_pref_off
    @user.thumbnail_maps = false

    html = render(map_with(@obs, @user))

    assert_equal("", html)
  end

  def test_renders_nothing_for_logged_out_viewer
    html = render(map_with(@obs, nil))

    assert_equal("", html)
  end

  private

  def map_with(obs, user)
    Views::Controllers::Observations::Show::Details::ThumbnailMap.new(
      obs: obs, user: user
    )
  end
end
