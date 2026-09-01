# frozen_string_literal: true

require "test_helper"

class NavbarTextTest < ComponentTestCase
  def test_renders_default_div_wrapper
    html = render_component(Components::Navbar::Text.new) { "Page" }

    assert_html(html, "div.navbar-text", text: "Page")
  end

  def test_renders_custom_element
    html = render_component(Components::Navbar::Text.new(element: :li)) do
      "Sort by:"
    end

    assert_html(html, "li.navbar-text", text: "Sort by:")
  end

  def test_renders_with_custom_class
    html = render_component(
      Components::Navbar::Text.new(class: "mx-0 hidden-xs")
    ) { "Page" }

    assert_html(html, "div.navbar-text.mx-0.hidden-xs", text: "Page")
  end

  def test_renders_with_data_attributes
    html = render_component(
      Components::Navbar::Text.new(data: { foo: "bar" })
    ) { "Page" }

    assert_html(html, "div.navbar-text",
                attribute: { "data-foo" => "bar" })
  end
end
