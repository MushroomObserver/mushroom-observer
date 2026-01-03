# frozen_string_literal: true

require "test_helper"

module Sidebar
  class IndexesTest < ComponentTestCase
    def test_renders_heading_and_links
      html = render_component

      # Should have heading with "Indexes:" text
      assert_includes(html, :INDEXES.t)

      # Should include navigation links
      assert_includes(html, "nav_articles_link")
      assert_includes(html, "nav_herbaria_link")
      assert_includes(html, "nav_locations_link")
      assert_includes(html, "nav_name_observations_link")
      assert_includes(html, "nav_projects_link")

      # Should have indent class on links
      assert_includes(html, "list-group-item indent")

      # Should have nav-active data attributes for active link tracking
      assert_includes(html, "data-nav-active-target=\"link\"")
    end

    def test_heading_has_correct_css_classes
      html = render_component

      # Heading should have the disabled and font-weight-bold classes
      assert_html(
        html,
        "div.list-group-item.disabled.font-weight-bold"
      )
    end

    private

    def render_component
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Indexes.new(classes: classes))
    end
  end
end
