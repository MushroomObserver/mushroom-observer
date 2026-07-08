# frozen_string_literal: true

require "test_helper"

class InputGroupTest < ComponentTestCase
  def test_renders_input_group_div
    html = render_component(Components::InputGroup.new) { "content" }

    assert_html(html, "div.input-group", text: "content")
  end

  def test_renders_with_custom_class
    html = render_component(
      Components::InputGroup.new(class: "page-input mx-2")
    ) { "content" }

    assert_html(html, "div.input-group.page-input.mx-2", text: "content")
  end

  def test_renders_with_data_attributes
    html = render_component(
      Components::InputGroup.new(data: { foo: "bar" })
    ) { "content" }

    assert_html(html, "div.input-group",
                attribute: { "data-foo" => "bar" })
  end
end
