# frozen_string_literal: true

require("test_helper")

class ObservationFragmentWhereGpsTest < ComponentTestCase
  def test_renders_nothing_without_user
    obs = observations(:minimal_unknown_obs)
    obs.update(lat: 45.5, lng: -122.6)

    html = render_where_gps(obs, user: nil)

    assert_equal("", html)
  end

  def test_renders_nothing_without_coordinates
    obs = observations(:minimal_unknown_obs)
    assert_nil(obs.lat)

    html = render_where_gps(obs, user: obs.user)

    assert_equal("", html)
  end

  def test_renders_gps_link_when_visible
    obs = observations(:minimal_unknown_obs)
    obs.update(lat: 45.5, lng: -122.6)

    html = render_where_gps(obs, user: obs.user)

    assert_html(html, "li.obs-where-gps.indent")
    assert_html(html, "a[href*='/observations/#{obs.id}/map']")
    assert_no_html(html, "i")
  end

  def test_renders_hidden_notice_when_gps_hidden
    obs = observations(:minimal_unknown_obs)
    obs.update(lat: 45.5, lng: -122.6, gps_hidden: true)

    # Owner can still reveal their own hidden coordinates.
    html = render_where_gps(obs, user: obs.user)

    assert_html(html, "a[href*='/observations/#{obs.id}/map']")
    assert_html(html, "i", text: "(#{:show_observation_gps_hidden.t})")
  end

  def test_hides_gps_link_when_hidden_from_non_owner
    obs = observations(:minimal_unknown_obs)
    obs.update(lat: 45.5, lng: -122.6, gps_hidden: true)
    viewer = users(:rolf)
    assert_not_equal(obs.user, viewer)

    html = render_where_gps(obs, user: viewer)

    assert_no_html(html, "a[href*='/observations/#{obs.id}/map']")
    assert_html(html, "i", text: "(#{:show_observation_gps_hidden.t})")
  end

  private

  def render_where_gps(obs, user:)
    render(
      Components::ObservationFragment::WhereGps.new(obs: obs, user: user)
    )
  end
end
