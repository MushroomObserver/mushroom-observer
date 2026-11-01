# frozen_string_literal: true

require "test_helper"

class ButtonGroupTest < ComponentTestCase
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_renders_button_group_with_role
    html = render_component(Components::ButtonGroup.new) { "content" }

    assert_html(html, ".btn-group[role='group']", text: "content")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_renders_with_custom_class
    html = render_component(
      Components::ButtonGroup.new(class: "pb-1 mt-3")
    ) { "content" }

    assert_html(html, ".btn-group.pb-1.mt-3[role='group']",
                text: "content")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_role_is_overridable
    html = render_component(
      Components::ButtonGroup.new(role: "toolbar")
    ) { "content" }

    assert_html(html, ".btn-group[role='toolbar']", text: "content")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_renders_with_data_attributes
    html = render_component(
      Components::ButtonGroup.new(data: { foo: "bar" })
    ) { "content" }

    assert_html(html, ".btn-group", attribute: { "data-foo" => "bar" })
  end
end
