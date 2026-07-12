# frozen_string_literal: true

require("test_helper")

class Views::Layouts::TopNav
  class SearchBarTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      viewer = @user
      controller.define_singleton_method(:current_user) { viewer }
      session = { search_type: "observations" }
      controller.define_singleton_method(:session) { session }
    end

    def test_help_toggle_visible_when_type_has_help
      html = render_bar(help_types: [:observations])

      # Rendered as <a> (link) not <button>; href serves as the
      # collapse target (no separate data-target needed).
      assert_html(html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='helpToggle']" \
                  "[href='#search_bar_help']" \
                  "[aria-controls='search_bar_help']" \
                  "[aria-expanded='false']")
      assert_html(html,
                  "a[data-search-type-target='helpToggle'] span.glyphicon")
      assert_html(html,
                  "a[data-search-type-target='helpToggle'] span.sr-only",
                  text: :search_bar_help.t.as_displayed)
      assert_no_html(html,
                     "a[data-search-type-target='helpToggle'].d-none")
      # Rendered via CollapseToggle's button:/size: kwarg, not via raw
      # btn/btn-link strings — see BAR_TOGGLE_CLASSES.
      assert_html(html,
                  "a[data-search-type-target='helpToggle'].btn.btn-link")
    end

    def test_help_toggle_hidden_when_type_has_no_help
      html = render_bar(help_types: [])

      assert_html(html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='helpToggle'].d-none")
    end

    def test_form_toggle_visible_when_type_has_form
      html = render_bar(form_types: [:observations])

      assert_html(html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='formToggle']" \
                  "[href='#search_nav_form']" \
                  "[aria-controls='search_nav_form']" \
                  "[aria-expanded='false']")
      assert_html(html,
                  "a[data-search-type-target='formToggle'] span.glyphicon")
      assert_html(html,
                  "a[data-search-type-target='formToggle'] span.sr-only",
                  text: :search_bar_more_options.l.as_displayed)
      assert_no_html(html,
                     "a[data-search-type-target='formToggle'].d-none")
      assert_html(html,
                  "a[data-search-type-target='formToggle'].btn.btn-link")
    end

    def test_form_toggle_hidden_when_type_has_no_form
      html = render_bar(form_types: [])

      assert_html(html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='formToggle'].d-none")
    end

    def test_renders_login_reminder_when_no_user
      controller.define_singleton_method(:current_user) { nil }
      html = render_bar

      assert_html(html, "strong.navbar-text",
                  text: :app_login_reminder.t.as_displayed)
      assert_no_html(html, "[data-toggle='collapse']")
    end

    private

    def render_bar(help_types: [:observations], form_types: [:observations])
      render(Views::Layouts::TopNav::SearchBar.new(
               search_help_types: help_types,
               search_form_types: form_types
             ))
    end
  end
end
