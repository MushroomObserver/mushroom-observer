# frozen_string_literal: true

require "test_helper"

module Sidebar
  class IndexesTest < ComponentTestCase
    include Tabs::Sidebar::IndexesHelper
    include Rails.application.routes.url_helpers

    def setup
      super
      @original_default_url_options =
        Rails.application.routes.default_url_options.dup
      Rails.application.routes.default_url_options[:host] = "test.host"
    end

    def teardown
      Rails.application.routes.default_url_options.replace(
        @original_default_url_options
      )
      super
    end

    def test_renders_heading_and_links
      html = render_component

      # Should have heading with "Indexes:" text
      assert_includes(html, :INDEXES.t)

      # Should include navigation links
      assert_html(html, "a#nav_articles_link")
      assert_html(html, "a#nav_herbaria_link")
      assert_html(html, "a#nav_locations_link")
      assert_html(html, "a#nav_name_observations_link")
      assert_html(html, "a#nav_projects_link")

      # Should have indent class on links
      assert_html(html, ".list-group-item.indent")

      # Should have nav-active data attributes for active link tracking
      assert_html(html, "a[data-nav-active-target='link']")
    end

    def test_heading_has_correct_css_classes
      html = render_component

      # Heading should have the disabled and font-weight-bold classes
      assert_html(html, ".list-group-item.disabled.font-weight-bold")
    end

    private

    def render_component
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Section.new(
               heading_key: :INDEXES,
               tabs: sidebar_indexes_tabs,
               classes: classes
             ))
    end
  end
end
