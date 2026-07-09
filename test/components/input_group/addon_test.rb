# frozen_string_literal: true

require "test_helper"

class Components::InputGroup::AddonTest < ComponentTestCase
  def test_renders_default_btn_variant
    html = render_component(Components::InputGroup::Addon.new) { "Go" }

    assert_html(html, "span.input-group-btn", text: "Go")
  end

  def test_renders_addon_variant
    html = render_component(
      Components::InputGroup::Addon.new(variant: :addon)
    ) { "@" }

    assert_html(html, "span.input-group-addon", text: "@")
  end

  def test_renders_with_custom_class
    html = render_component(
      Components::InputGroup::Addon.new(class: "extra")
    ) { "Go" }

    assert_html(html, "span.input-group-btn.extra", text: "Go")
  end
end
