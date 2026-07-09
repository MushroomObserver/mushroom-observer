# frozen_string_literal: true

require "test_helper"

class Views::Layouts::Sidebar
  class LanguagesTest < ComponentTestCase
    Browser = Struct.new(:bot?) do
      def bot?
        self[:bot?]
      end
    end
    Request = Struct.new(:url)

    def test_renders_language_toggle
      html = render_component

      # The toggle IS the "Languages:" label + current-locale flag —
      # no separate dropdown affordance. It's also the collapse
      # trigger: clicking it expands/collapses the language list
      # inline, rather than opening a floating menu.
      assert_html(html, "##{Languages::TOGGLE_ID}.list-group-item")
      assert_html(html, "##{Languages::TOGGLE_ID}[data-toggle='collapse']")
      assert_html(html,
                  "##{Languages::TOGGLE_ID}[href='##{Languages::COLLAPSE_ID}']")
      assert_includes(html, :app_languages.t)

      # Current language flag emoji — no image asset (flags are
      # emoji text via Languages::FLAG_EMOJI, not PNGs).
      assert_html(html, "##{Languages::TOGGLE_ID} span.lang-flag-emoji",
                  text: Languages::FLAG_EMOJI.fetch(I18n.locale.to_s))
      assert_no_html(html, "img.lang-flag")

      # Chevron pair — reuses Panel's established collapse-icon
      # convention (CSS flips visibility via the `.collapsed` class).
      assert_html(html,
                  "##{Languages::TOGGLE_ID} " \
                  ".glyphicon-chevron-down.active-icon")
      assert_html(html, "##{Languages::TOGGLE_ID} .glyphicon-chevron-up")

      # Order: "Languages:" label, then the flag, then the caret —
      # not flag-first. Walk the toggle's child nodes (not a raw
      # string scan) so this checks actual DOM order.
      children = Nokogiri::HTML(html).at_css("##{Languages::TOGGLE_ID}").children
      label_index = children.index do |node|
        node.text? && node.text.include?(:app_languages.t)
      end
      flag_index = children.index do |node|
        node.name == "span" && node[:class]&.include?("lang-flag-emoji")
      end
      caret_index = children.index do |node|
        node[:class]&.include?("glyphicon-chevron-down")
      end
      assert_operator(label_index, :<, flag_index)
      assert_operator(flag_index, :<, caret_index)
    end

    def test_renders_collapsible_language_list
      html = render_component

      assert_html(html, "div.collapse##{Languages::COLLAPSE_ID}")

      # Should have links for all non-beta languages, each a flat
      # `list-group-item` (not wrapped in an extra div) so the whole
      # row stays clickable.
      Language.where.not(beta: true).order(:order).each do |lang|
        # `.indent` (not a deeper `pl-*`) — same left padding as the
        # toggle's own `pl-3`, so rows line up with "Languages:"
        # rather than sitting under it.
        assert_html(html,
                    "##{Languages::COLLAPSE_ID} " \
                    "a.list-group-item.indent#lang_drop_#{lang.locale}_link" \
                    "[data-locale='#{lang.locale}']")
        assert_html(html,
                    "#lang_drop_#{lang.locale}_link span.lang-flag-emoji",
                    text: Languages::FLAG_EMOJI.fetch(lang.locale))
        assert_includes(html, lang.name)
      end
    end

    private

    def render_component(browser: mock_human_browser)
      render(
        Languages.new(
          browser: browser,
          request: mock_request,
          languages: mock_languages
        )
      )
    end

    def mock_languages
      Language.where.not(beta: true).order(:order).to_a
    end

    def mock_human_browser
      Browser.new(false)
    end

    def mock_request
      Request.new("http://example.com/path?foo=bar")
    end
  end
end
