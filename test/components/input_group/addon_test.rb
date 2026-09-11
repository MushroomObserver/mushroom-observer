# frozen_string_literal: true

require "test_helper"

class Components::InputGroup::AddonTest < ComponentTestCase
  def test_renders_default_btn_variant
    html = render_component(Components::InputGroup::Addon.new) { "Go" }

    assert_html(html, "div.input-group-append", text: "Go")
    assert_no_html(html, ".input-group-text")
  end

  def test_renders_addon_variant
    html = render_component(
      Components::InputGroup::Addon.new(variant: :addon)
    ) { "@" }

    assert_html(html, "div.input-group-append span.input-group-text",
                text: "@")
  end

  def test_renders_prepend_position
    html = render_component(
      Components::InputGroup::Addon.new(position: :prepend)
    ) { "Go" }

    assert_html(html, "div.input-group-prepend", text: "Go")
  end

  def test_renders_with_custom_class
    html = render_component(
      Components::InputGroup::Addon.new(class: "extra")
    ) { "Go" }

    assert_html(html, "div.input-group-append.extra", text: "Go")
  end
end
