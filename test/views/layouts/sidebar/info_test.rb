# frozen_string_literal: true

require "test_helper"

class Views::Layouts::Sidebar
  class InfoTest < ComponentTestCase
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

      # Should have heading with "More:" text
      assert_includes(html, :app_more.t)

      # Should include navigation links
      assert_html(html, ".get_mobile_app_link")
      assert_html(html, ".introduction_link")
      assert_html(html, ".how_to_use_link")
      assert_html(html, ".donate_link")
      assert_html(html, ".how_to_help_link")
      assert_html(html, ".report_a_bug_link")
      assert_html(html, ".send_a_comment_link")
      assert_html(html, ".contributors_link")
      assert_html(html, ".site_stats_link")
      assert_html(html, ".translator_8217_s_note_link")
      assert_html(html, ".publications_link")
      assert_html(html, ".privacy_policy_link")

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
      render(Section.new(
               heading_key: :app_more,
               tabs: Tab::Sidebar::InfoActions.new.map(&:to_a),
               classes: classes
             ))
    end
  end
end
