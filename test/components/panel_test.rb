# frozen_string_literal: true

require("test_helper")

class PanelTest < UnitTestCase
  include ComponentTestHelper

  def test_basic_panel_with_heading_and_content
    component = Components::Panel.new(heading: "Test Heading") do
      "Panel content"
    end

    html = render(component)

    assert_includes(html, "panel panel-default")
    assert_includes(html, "panel-heading")
    assert_includes(html, "Test Heading")
    assert_includes(html, "panel-body")
    assert_includes(html, "Panel content")
  end

  def test_panel_with_footer
    component = Components::Panel.new(
      heading: "Test Heading",
      footer: "Footer text"
    ) do
      "Panel content"
    end

    html = render(component)

    assert_includes(html, "panel-footer")
    assert_includes(html, "Footer text")
  end

  def test_panel_with_custom_class
    component = Components::Panel.new(
      heading: "Test",
      panel_class: "custom-class"
    ) do
      "Content"
    end

    html = render(component)

    assert_includes(html, "panel panel-default custom-class")
  end

  def test_collapsible_panel
    component = Components::Panel.new(
      heading: "Click to expand",
      collapse: "test_panel",
      open: false
    ) do
      "Collapsible content"
    end

    html = render(component)

    assert_includes(html, 'id="test_panel"')
    assert_includes(html, "panel-collapse collapse")
    assert_includes(html, "panel-collapse-trigger")
    assert_not_includes(html, "panel-collapse collapse in")
  end

  def test_collapsible_panel_open
    component = Components::Panel.new(
      heading: "Click to collapse",
      collapse: "test_panel",
      open: true
    ) do
      "Expanded content"
    end

    html = render(component)

    assert_includes(html, "panel-collapse collapse in")
  end
end
