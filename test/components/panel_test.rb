# frozen_string_literal: true

require("test_helper")

class PanelTest < UnitTestCase
  include ComponentTestHelper

  def test_basic_panel_with_heading_and_content
    html = render(Components::Panel.new) do |panel|
      panel.render(Components::PanelHeading.new { "Test Heading" })
      panel.render(Components::PanelBody.new { "Panel content" })
    end

    assert_includes(html, "panel panel-default")
    assert_includes(html, "panel-heading")
    assert_includes(html, "Test Heading")
    assert_includes(html, "panel-body")
    assert_includes(html, "Panel content")
  end

  def test_panel_with_footer
    html = render(Components::Panel.new) do |panel|
      panel.render(Components::PanelHeading.new { "Test Heading" })
      panel.render(Components::PanelBody.new { "Panel content" })
      panel.render(Components::PanelFooter.new { "Footer text" })
    end

    assert_includes(html, "panel-footer")
    assert_includes(html, "Footer text")
  end

  def test_panel_with_custom_class
    html = render(Components::Panel.new(panel_class: "custom-class")) do |panel|
      panel.render(Components::PanelHeading.new { "Test" })
      panel.render(Components::PanelBody.new { "Content" })
    end

    assert_includes(html, "panel panel-default custom-class")
  end

  def test_panel_with_multiple_bodies
    html = render(Components::Panel.new) do |panel|
      panel.render(Components::PanelHeading.new { "Test" })
      panel.render(Components::PanelBody.new { "First body" })
      panel.render(Components::PanelBody.new { "Second body" })
    end

    assert_includes(html, "First body")
    assert_includes(html, "Second body")
  end

  def test_panel_with_thumbnail
    html = render(Components::Panel.new) do |panel|
      panel.render(Components::PanelHeading.new { "Test" })
      panel.render(Components::PanelThumbnail.new { "Thumbnail content" })
      panel.render(Components::PanelBody.new { "Body content" })
    end

    assert_includes(html, "thumbnail-container")
    assert_includes(html, "Thumbnail content")
  end
end
