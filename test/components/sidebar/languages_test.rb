# frozen_string_literal: true

require "test_helper"

module Sidebar
  class LanguagesTest < ComponentTestCase
    Browser = Struct.new(:bot?) do
      def bot?
        self[:bot?]
      end
    end
    Request = Struct.new(:url)
    def test_renders_language_dropdown
      html = render_component

      # Should have "Languages:" label
      assert_includes(html, :app_languages.t)

      # Should have dropdown toggle
      assert_html(html, "a#language_dropdown_toggle.dropdown-toggle")
      assert_html(html, "a[data-toggle='dropdown']")

      # Should have current language flag
      assert_includes(html, "flag-#{I18n.locale.downcase}.png")
      assert_html(html, "img.lang-flag")

      # Should have caret
      assert_html(html, "span.caret")

      # Should have dropdown menu
      assert_html(html, "ul#language_dropdown_menu.dropdown-menu")
    end

    def test_renders_language_links
      html = render_component

      # Should have links for all non-beta languages
      Language.where.not(beta: true).order(:order).each do |lang|
        assert_html(html, "a#lang_drop_#{lang.locale}_link")
        assert_includes(html, "flag-#{lang.locale}.png")
        assert_includes(html, lang.name)
      end
    end

    def test_renders_nothing_for_bots
      browser = mock_bot_browser
      html = render_component(browser: browser)

      # Should render nothing for bots
      assert_equal("", html)
    end

    def test_dropdown_has_correct_structure
      html = render_component

      # Should have proper nested structure
      assert_html(html, "div.list-group-item.pl-3.overflow-visible")
      assert_html(html, "div.dropdown")
      assert_html(html, "ul.dropdown-menu li")
    end

    private

    def render_component(browser: mock_human_browser)
      render(
        Components::Sidebar::Languages.new(
          browser: browser,
          request: mock_request
        )
      )
    end

    def mock_human_browser
      Browser.new(false)
    end

    def mock_bot_browser
      Browser.new(true)
    end

    def mock_request
      Request.new("http://example.com/path?foo=bar")
    end
  end
end
