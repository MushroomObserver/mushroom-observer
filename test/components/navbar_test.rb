# frozen_string_literal: true

require "test_helper"

class NavbarTest < ComponentTestCase
  def test_variant_default_renders_nav_landmark
    html = render_component(
      Components::Navbar.new(variant: :default,
                             class: "hidden-print mb-2", id: "top_nav")
    ) { "Content" }

    assert_html(html, "nav.navbar.navbar-flex.navbar-default.p-0" \
                       ".hidden-print.mb-2#top_nav", text: "Content")
  end

  def test_variant_inverse_with_explicit_element_overrides_nav_default
    html = render_component(
      Components::Navbar.new(variant: :inverse, element: :div,
                             class: "sidebar-nav",
                             data_controller: "nav-active")
    ) { "Content" }

    assert_html(html, "div.navbar.navbar-flex.navbar-inverse.p-0" \
                       ".sidebar-nav[data-controller='nav-active']",
                text: "Content")
  end

  def test_link_classes_constant
    assert_equal(%w[navbar-link px-0],
                 Components::Navbar::LINK_CLASSES)
  end

  def test_form_class_constant
    assert_equal("navbar-form", Components::Navbar::FORM_CLASS)
  end
end
