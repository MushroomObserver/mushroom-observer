# frozen_string_literal: true

require("test_helper")

class PanelTest < UnitTestCase
  include ComponentTestHelper

  def test_panel_with_heading_and_collapsible_content
    edit_link = view_context.link_to("Edit", "/edit", class: "btn btn-sm")
    html = render(Components::Panel.new(
                    collapsible: true,
                    collapse_id: "collapsing_panel",
                    expanded: false,
                    collapse_message: "Show details"
                  )) do |panel|
      panel.with_heading { "Test Heading" }
      panel.with_heading_links { edit_link }

      panel.with_body { "Panel content" }
      panel.with_body(collapse: true) { "Collapsing content" }
      panel.with_footer { "Footer content" }
    end

    assert_includes(html, "panel panel-default")
    assert_includes(html, "panel-heading")
    assert_includes(html, "Test Heading")
    assert_includes(html, "panel-collapse collapse")
    assert_includes(html, "Show details")
    assert_includes(html, "panel-body")
    assert_includes(html, "Panel content")
    assert_includes(html, "Collapsing content")
    assert_includes(html, "Footer content")

    # Test that panel-collapse-trigger is nested in span.panel-heading-links
    assert_nested(
      html,
      parent_selector: "span.panel-heading-links",
      child_selector: "a.panel-collapse-trigger"
    )
    # Test that other heading links are printed
    assert_nested(
      html,
      parent_selector: "span.panel-heading-links",
      child_selector: "a.btn",
      text: "Edit"
    )

    # Test that collapsing content is nested properly
    assert_text_in_nested_selector(
      html,
      text: "Collapsing content",
      parent: "#collapsing_panel",
      child: ".panel-body"
    )

    # Test that collapse message is within the trigger link
    assert_nested(
      html,
      parent_selector: "a.panel-collapse-trigger",
      child_selector: "span.font-weight-normal",
      text: "Show details"
    )
  end

  def test_panel_with_footer
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Test Heading" }
      panel.with_body { "Panel content" }
      panel.with_footer { "Footer text" }
    end

    assert_includes(html, "panel-footer")
    assert_includes(html, "Footer text")
  end

  def test_panel_with_custom_class
    html = render(Components::Panel.new(panel_class: "custom-class")) do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "Content" }
    end

    assert_includes(html, "panel panel-default custom-class")
  end

  def test_panel_with_multiple_bodies
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "First body" }
      panel.with_body { "Second body" }
    end

    assert_includes(html, "First body")
    assert_includes(html, "Second body")
  end

  def test_panel_with_thumbnail
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail { "Thumbnail content" }
      panel.with_body { "Body content" }
    end

    assert_includes(html, "thumbnail-container")
    assert_includes(html, "Thumbnail content")
  end
end
