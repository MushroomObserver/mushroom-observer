# frozen_string_literal: true

require("test_helper")

class PanelTest < UnitTestCase
  include ComponentTestHelper

  def test_panel_with_heading_and_collapsible_content
    edit_link = view_context.link_to("Edit", "/edit", class: "btn btn-sm")
    html = render(Components::Panel.new(
                    collapsible: true,
                    collapse_target: "#collapsing_panel",
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

  def test_panel_with_carousel_for_thumbnail
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail(classes: "carousel") { "Carousel content" }
      panel.with_body { "Body content" }
    end

    assert_not_includes(html, "thumbnail-container")
    assert_includes(html, "carousel")
    assert_includes(html, "Carousel content")
  end

  def test_panel_with_multiple_footers
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "Content" }
      panel.with_footer { "First footer" }
      panel.with_footer { "Second footer" }
      panel.with_footer { "Third footer" }
    end

    assert_includes(html, "First footer")
    assert_includes(html, "Second footer")
    assert_includes(html, "Third footer")

    # Verify all footers are wrapped in panel-footer divs
    footer_count = html.scan('class="panel-footer"').count
    assert_equal(3, footer_count,
                 "Expected 3 panel-footer divs for 3 footers")
  end

  def test_panel_with_sizing_enabled
    html = render(Components::Panel.new(sizing: true)) do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail { "Thumbnail" }
      panel.with_body { "Body content" }
    end

    # Test that thumbnail and body are wrapped in panel-sizing div
    assert_includes(html, "panel-sizing")
    assert_nested(
      html,
      parent_selector: "div.panel-sizing",
      child_selector: "div.thumbnail-container"
    )
    assert_nested(
      html,
      parent_selector: "div.panel-sizing",
      child_selector: "div.panel-body"
    )
  end

  def test_panel_without_sizing
    html = render(Components::Panel.new(sizing: false)) do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail { "Thumbnail" }
      panel.with_body { "Body content" }
    end

    # Test that panel-sizing div is NOT present
    assert_not_includes(
      html, "panel-sizing",
      "panel-sizing should not be present when sizing is false"
    )
    # But thumbnail and body should still be rendered
    assert_includes(html, "thumbnail-container")
    assert_includes(html, "panel-body")
  end

  def test_panel_with_interactive_image_thumbnail
    user = users(:rolf)
    obs = observations(:coprinus_comatus_obs)
    image = obs.thumb_image

    component = Components::Panel.new
    html = render(component) do |panel|
      panel.with_heading { "Observation" }
      panel.with_thumbnail do
        render(Components::InteractiveImage.new(
                 user: user,
                 image: image,
                 size: :thumbnail,
                 votes: false
               ))
      end
      panel.with_body { "Observation details" }
    end

    # Should contain the image
    assert_includes(html, "thumbnail-container")
    assert_nested(
      html,
      parent_selector: "div.thumbnail-container",
      child_selector: "img"
    )
    # Should have the image ID in the HTML
    assert_includes(html, "image_#{image.id}")
  end

  def test_panel_with_interactive_image_and_sizing
    user = users(:rolf)
    obs = observations(:coprinus_comatus_obs)
    image = obs.thumb_image

    component = Components::Panel.new(sizing: true)
    html = render(component) do |panel|
      panel.with_heading { "Observation" }
      panel.with_thumbnail do
        render(Components::InteractiveImage.new(
                 user: user,
                 image: image,
                 size: :thumbnail,
                 votes: false
               ))
      end
      panel.with_body { "Details" }
    end

    # Should have panel-sizing wrapper
    assert_includes(html, "panel-sizing")
    # Image should be nested in panel-sizing > thumbnail-container
    assert_nested(
      html,
      parent_selector: "div.panel-sizing",
      child_selector: "div.thumbnail-container"
    )
    assert_nested(
      html,
      parent_selector: "div.thumbnail-container",
      child_selector: "img"
    )
  end

  def test_panel_with_unwrapped_body_for_list_group
    html = render(Components::Panel.new) do |panel|
      panel.with_heading { "Comments" }
      panel.with_body(wrapper: false) do
        view_context.tag.ul(class: "list-group") do
          view_context.tag.li("Comment 1", class: "list-group-item")
        end
      end
    end

    # List group should be direct child of panel, not wrapped in panel-body
    assert_includes(html, "list-group")
    assert_no_match(/<div class="panel-body">.*<ul class="list-group">/m, html)
    # Panel should contain list-group directly
    pattern = /<div class="panel panel-default">.*<ul class="list-group">/m
    assert_match(pattern, html)
  end
end
