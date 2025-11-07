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

  def test_panel_with_image_thumbnail
    obs = observations(:coprinus_comatus_obs)
    image = obs.thumb_image

    component = Components::Panel.new
    html = render(component) do |panel|
      panel.with_heading { "Observation" }
      panel.with_thumbnail do
        view_context.tag.img(
          src: "/images/#{image.id}/thumbnail",
          alt: "Thumbnail",
          class: "img-thumbnail"
        )
      end
      panel.with_body { "Observation details" }
    end

    # Should contain the image in thumbnail container
    assert_includes(html, "thumbnail-container")
    assert_nested(
      html,
      parent_selector: ".thumbnail-container",
      child_selector: "img"
    )
  end

  def test_panel_with_image_and_sizing
    obs = observations(:coprinus_comatus_obs)
    image = obs.thumb_image

    component = Components::Panel.new(sizing: true)
    html = render(component) do |panel|
      panel.with_heading { "Observation" }
      panel.with_thumbnail do
        view_context.tag.img(
          src: "/images/#{image.id}/thumbnail",
          alt: "Thumbnail",
          class: "img-thumbnail"
        )
      end
      panel.with_body { "Details" }
    end

    # Should have panel-sizing wrapper
    assert_includes(html, "panel-sizing")
    # Image should be nested in panel-sizing > thumbnail-container
    assert_nested(
      html,
      parent_selector: ".panel-sizing",
      child_selector: ".thumbnail-container"
    )
    assert_nested(
      html,
      parent_selector: ".thumbnail-container",
      child_selector: "img"
    )
  end
end
