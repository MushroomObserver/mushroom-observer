# frozen_string_literal: true

require "test_helper"

class Views::Layouts::Sidebar
  class ObservationsTest < ComponentTestCase
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

      # Should have heading with "Observations:" text
      assert_includes(html, :app_observations_left.t)

      # Should include navigation links
      assert_html(html, ".latest_link")
      assert_html(html, ".create_observation_link")
      assert_html(html, ".your_observations_link")
      assert_html(html, ".help_identify_link")

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

    def test_renders_only_latest_link_for_guest_users
      html = render_component(user: nil)

      # Should have heading
      assert_includes(html, :app_observations_left.t)

      # Should have latest observations link (available to all)
      assert_html(html, ".latest_link")

      # Should NOT have user-only links
      assert_no_html(html, ".create_observation_link")
      assert_no_html(html, ".your_observations_link")
      assert_no_html(html, ".help_identify_link")
    end

    private

    def render_component(user: users(:rolf))
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Section.new(
               heading_key: :app_observations_left,
               tabs: Tab::Sidebar::ObservationsActions.new(user: user).
                     map(&:to_a),
               classes: classes
             ))
    end
  end
end
