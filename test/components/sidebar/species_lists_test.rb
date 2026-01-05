# frozen_string_literal: true

require "test_helper"

module Sidebar
  class SpeciesListsTest < ComponentTestCase
    include Tabs::Sidebar::SpeciesListsHelper
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

      # Should have heading with "Species Lists:" text
      assert_includes(html, :app_species_list.t)

      # Should include navigation links
      assert_html(html, "#nav_your_species_lists_link")
      assert_html(html, "#nav_species_lists_link")
      assert_html(html, "#nav_new_species_list_link")

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

    def test_renders_only_all_lists_link_for_guest_users
      html = render_component(user: nil)

      # Should have heading
      assert_includes(html, :app_species_list.t)

      # Should have all lists link (available to all)
      assert_html(html, "#nav_species_lists_link")

      # Should NOT have user-only links
      assert_no_html(html, "#nav_your_species_lists_link")
      assert_no_html(html, "#nav_new_species_list_link")
    end

    private

    def render_component(user: users(:rolf))
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Section.new(
               heading_key: :app_species_list,
               tabs: sidebar_species_lists_tabs(user),
               classes: classes
             ))
    end
  end
end
