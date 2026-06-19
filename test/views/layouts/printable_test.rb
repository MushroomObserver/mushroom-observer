# frozen_string_literal: true

require("test_helper")

# Tests for `Views::Layouts::Printable` — the print-friendly
# application layout. Selected by `Views::FullPageBase#around_template`
# when `session[:layout] == "printable"`. Has none of the sidebar /
# top_nav / header chrome — just doctype, head (charset, RSS link,
# title, favicon, OG tags, inline print CSS), and a body containing
# the action's rendered content.
class Views::Layouts::PrintableTest < ComponentTestCase
  # Renders a known-shape page via a FullPageBase subclass under the
  # printable layout, so the test exercises the actual wrap path
  # (`FullPageBase#around_template` → `capture` → render Printable
  # with the captured HTML).
  class FakePage < Views::FullPageBase
    def view_template
      content_for(:document_title, "MyPage")
      div(id: "inner-page") { plain("INNER") }
    end
  end

  def setup
    super
    stub_printable_session!
  end

  def test_renders_basic_document_skeleton
    html = render(FakePage.new)

    assert_match(/\A<!doctype html><html\b/, html)
    assert_html(html, "html[lang='en']")
    assert_html(html, "html > head")
    assert_html(html, "html > body")
  end

  def test_head_contains_charset_and_print_metadata
    html = render(FakePage.new)

    assert_html(html, "head > meta[charset='utf-8']")
    assert_html(html, "head > link[rel='SHORTCUT ICON']")
    assert_html(html, "head > meta[property='og:title']")
    assert_html(html, "head > meta[property='og:description']")
    assert_html(html, "head > meta[property='og:image']")
  end

  def test_head_contains_rss_discovery_link
    html = render(FakePage.new)

    assert_html(html,
                "head > link[rel='alternate'][type='application/rss+xml']")
  end

  def test_head_contains_document_title_from_content_for
    html = render(FakePage.new)

    # `:app_title.l` may contain HTML entities; route through
    # `as_displayed` so Nokogiri's text comparison matches the
    # decoded form. See testing.md.
    assert_html(html, "head > title",
                text: "#{:app_title.l.as_displayed}: MyPage")
  end

  def test_head_contains_inline_print_style
    html = render(FakePage.new)

    style = Nokogiri::HTML5.parse(html).at_css("head > style")&.text.to_s
    assert_match(/page-break-before:\s*always/, style)
    assert_match(/page-break-inside:\s*avoid/, style)
  end

  def test_body_renders_inner_action_content
    html = render(FakePage.new)

    assert_html(html, "body > #inner-page", text: "INNER")
  end

  def test_no_application_chrome
    html = render(FakePage.new)

    assert_no_html(html, "#main_container")
    assert_no_html(html, "#sidebar")
    assert_no_html(html, "#right_side")
    assert_no_html(html, "#top_nav")
    assert_no_html(html, "#header")
    assert_no_html(html, "#page_flash")
  end

  private

  # Sessions are disabled in `ComponentTestCase`; stub the read of
  # `session[:layout]` that `FullPageBase#layout_class` does.
  def stub_printable_session!
    stub = { layout: "printable" }
    controller.define_singleton_method(:session) { stub }
  end
end
