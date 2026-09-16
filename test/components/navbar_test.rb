# frozen_string_literal: true

require "test_helper"

class NavbarTest < ComponentTestCase
  def test_variant_light_renders_nav_landmark
    html = render_component(
      Components::Navbar.new(variant: :light,
                             class: "hidden-print mb-2", id: "top_nav")
    ) { "Content" }

    assert_html(html, "nav.navbar.navbar-light.p-0" \
                       ".hidden-print.mb-2#top_nav", text: "Content")
  end

  def test_variant_dark_with_explicit_element_overrides_nav_default
    html = render_component(
      Components::Navbar.new(variant: :dark, element: :div,
                             class: "sidebar-nav",
                             data_controller: "nav-active")
    ) { "Content" }

    assert_html(html, "div.navbar.navbar-dark.p-0" \
                       ".sidebar-nav[data-controller='nav-active']",
                text: "Content")
  end

  def test_padding_prop_overrides_default_zero_padding
    html = render_component(
      Components::Navbar.new(variant: :light, id: "top_nav",
                             padding: "py-2 px-0")
    ) { "Content" }

    assert_html(html, "nav.navbar.navbar-light.py-2.px-0#top_nav",
                text: "Content")
    assert_no_html(html, ".p-0")
  end
end
