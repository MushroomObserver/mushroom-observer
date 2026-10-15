# frozen_string_literal: true

require "test_helper"

class NavbarTest < ComponentTestCase
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_variant_default_renders_nav_landmark
    html = render_component(
      Components::Navbar.new(variant: :default,
                             class: "hidden-print mb-2", id: "top_nav")
    ) { "Content" }

    assert_html(html, "nav.navbar.navbar-flex.navbar-default" \
                       ".hidden-print.mb-2#top_nav", text: "Content")
  end

  # rubocop:disable-next MO/RedundantTagInSelector
  def test_variant_inverse_with_explicit_element_overrides_nav_default
    html = render_component(
      Components::Navbar.new(variant: :inverse, element: :div,
                             class: "sidebar-nav",
                             data_controller: "nav-active")
    ) { "Content" }

    assert_html(html, "div.navbar.navbar-flex.navbar-inverse" \
                       ".sidebar-nav[data-controller='nav-active']",
                text: "Content")
  end

  def test_flex_false_omits_bridge_class
    html = render_component(
      Components::Navbar.new(variant: :default, element: :div,
                             flex: false, id: "search_nav")
    ) { "Content" }

    assert_html(html, ".navbar.navbar-default#search_nav", text: "Content")
    assert_no_html(html, ".navbar-flex")
  end

  def test_link_class_constant
    assert_equal("navbar-link", Components::Navbar::LINK_CLASS)
  end

  def test_link_classes_constant
    assert_equal(%w[navbar-link px-0],
                 Components::Navbar::LINK_CLASSES)
  end

  def test_form_class_constant
    assert_equal("navbar-form", Components::Navbar::FORM_CLASS)
  end

  def test_nav_right_left_class_constants
    assert_equal("navbar-nav", Components::Navbar::NAV_CLASS)
    assert_equal("navbar-right", Components::Navbar::RIGHT_CLASS)
    assert_equal("navbar-left", Components::Navbar::LEFT_CLASS)
  end
end
