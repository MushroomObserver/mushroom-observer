# frozen_string_literal: true

require("test_helper")

class PanelTest < ComponentTestCase
  def test_panel_with_heading_and_collapsible_content
    edit_link = view_context.link_to("Edit", "/edit", class: "btn btn-sm")
    html = render_panel(collapsible: true,
                        collapse_target: "#collapsing_panel",
                        expanded: false,
                        collapse_message: "Show details") do |panel|
      panel.with_heading { "Test Heading" }
      panel.with_heading_links { edit_link }

      panel.with_body { "Panel content" }
      panel.with_body(collapse: true) { "Collapsing content" }
      panel.with_footer { "Footer content" }
    end

    assert_includes(html, "card")
    assert_includes(html, "card-header")
    assert_includes(html, "Test Heading")
    assert_html(html, "div.collapse.card-collapse")
    assert_includes(html, "Show details")
    assert_includes(html, "card-body")
    assert_includes(html, "Panel content")
    assert_includes(html, "Collapsing content")
    assert_includes(html, "Footer content")

    # Test that panel-collapse-trigger is nested in span.card-header-links
    assert_nested(
      html,
      parent_selector: "span.card-header-links",
      child_selector: "a.panel-collapse-trigger"
    )
    # Test that other heading links are printed
    assert_nested(
      html,
      parent_selector: "span.card-header-links",
      child_selector: "a.btn",
      text: "Edit"
    )

    # Test that collapsing content is nested properly
    assert_text_in_nested_selector(
      html,
      text: "Collapsing content",
      parent: "#collapsing_panel",
      child: ".card-body"
    )

    # Test that collapse message is within the trigger button
    assert_nested(
      html,
      parent_selector: "a.panel-collapse-trigger",
      child_selector: "span.font-weight-normal",
      text: "Show details"
    )
  end

  def test_panel_with_footer
    html = render_panel do |panel|
      panel.with_heading { "Test Heading" }
      panel.with_body { "Panel content" }
      panel.with_footer { "Footer text" }
    end

    assert_includes(html, "card-footer")
    assert_includes(html, "Footer text")
  end

  def test_panel_with_custom_class
    html = render_panel(panel_class: "custom-class") do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "Content" }
    end

    assert_includes(html, "card custom-class")
  end

  def test_panel_with_multiple_bodies
    html = render_panel do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "First body" }
      panel.with_body { "Second body" }
    end

    assert_includes(html, "First body")
    assert_includes(html, "Second body")
  end

  def test_panel_with_body_id_and_data
    html = render_panel do |panel|
      panel.with_heading { "Test" }
      panel.with_body(classes: "p-0", id: "my_section",
                      data: { controller: "section-update",
                              section_update_user_value: 42 }) do
        "Body content"
      end
    end

    assert_html(html, "div.card-body.p-0#my_section" \
                      "[data-controller='section-update']" \
                      "[data-section-update-user-value='42']",
                text: "Body content")
  end

  def test_panel_with_thumbnail
    html = render_panel do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail { "Thumbnail content" }
      panel.with_body { "Body content" }
    end

    assert_includes(html, "thumbnail-container")
    assert_includes(html, "Thumbnail content")
  end

  def test_panel_with_carousel_for_thumbnail
    html = render_panel do |panel|
      panel.with_heading { "Test" }
      panel.with_thumbnail(classes: "carousel") { "Carousel content" }
      panel.with_body { "Body content" }
    end

    assert_not_includes(html, "thumbnail-container")
    assert_includes(html, "carousel")
    assert_includes(html, "Carousel content")
  end

  def test_panel_with_multiple_footers
    html = render_panel do |panel|
      panel.with_heading { "Test" }
      panel.with_body { "Content" }
      panel.with_footer { "First footer" }
      panel.with_footer { "Second footer" }
      panel.with_footer { "Third footer" }
    end

    assert_includes(html, "First footer")
    assert_includes(html, "Second footer")
    assert_includes(html, "Third footer")

    # Verify all footers are wrapped in card-footer divs
    footer_count = html.scan('class="card-footer"').count
    assert_equal(3, footer_count,
                 "Expected 3 card-footer divs for 3 footers")
  end

  def test_panel_with_interactive_image_thumbnail
    user = users(:rolf)
    obs = observations(:coprinus_comatus_obs)
    image = obs.thumb_image

    html = render_panel do |panel|
      panel.with_heading { "Observation" }
      panel.with_thumbnail { render_interactive_image(user:, image:) }
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

  def test_panel_with_unwrapped_body_for_list_group
    html = render_panel do |panel|
      panel.with_heading { "Comments" }
      panel.with_body(wrapper: false) do
        view_context.tag.ul(class: "list-group") do
          view_context.tag.li("Comment 1", class: "list-group-item")
        end
      end
    end

    # List group should be direct child of panel, not wrapped in card-body
    assert_includes(html, "list-group")
    # ul.list-group should NOT be inside .card-body
    assert_no_html(html, ".card-body ul.list-group")
    # ul.list-group should be a (descendant) child of .card
    assert_html(html, ".card > ul.list-group")
  end

  private

  def render_panel(**, &block)
    render(Components::Panel.new(**), &block)
  end

  def render_interactive_image(user:, image:)
    render(Components::InteractiveImage.new(
             user: user, image: image, size: :thumbnail, votes: false
           ))
  end
end
