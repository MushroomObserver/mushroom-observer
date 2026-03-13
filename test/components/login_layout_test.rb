# frozen_string_literal: true

require "test_helper"

class LoginLayoutTest < ComponentTestCase
  def test_renders_logo_mobile_only
    html = render_component

    assert_html(html, "div.text-center.visible-xs-block")
    assert_html(html, "img.logo-trim[alt='MO Logo'][src='/logo-trim.png']")
  end

  def test_renders_heading
    html = render_component

    assert_html(html, "h2.h3.text-center")
    assert_includes(html, "Mushroom Observer (MO)")
  end

  def test_renders_description
    html = render_component

    assert_includes(html, :login_layout_description.t)
  end

  def test_renders_container
    html = render_component

    assert_html(html, "div.container-text")
  end

  def test_renders_html_comments
    html = render_component

    assert_includes(html, "<!-- LOGIN LAYOUT -->")
    assert_includes(html, "<!-- /LOGIN LAYOUT -->")
  end

  private

  def render_component
    render(Components::LoginLayout.new)
  end
end
