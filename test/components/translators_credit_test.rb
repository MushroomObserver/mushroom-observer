# frozen_string_literal: true

require "test_helper"

# Tests for TranslatorsCredit component conditional rendering
class TranslatorsCreditTest < ComponentTestCase
  def teardown
    Language.ignore_usage
    super
  end

  def test_does_not_render_for_official_language_without_tracking
    I18n.with_locale(:en) do
      html = render_component
      assert_equal("", html)
    end
  end

  def test_renders_translators_credit_for_unofficial_language
    I18n.with_locale(:fr) do
      html = render_component

      assert_html(html, "#translators_credit.hidden-print")
      assert_html(html, "hr")
      # Should render credit section with user links
      assert_html(html, "a[class^='user_link_']")
      # Should not render edit links when not tracking
      assert_no_html(html, "a#translations_for_page_link")
    end
  end

  def test_renders_translation_links_when_tracking_usage
    Language.track_usage
    I18n.with_locale(:en) do
      html = render_component

      assert_html(html, "#translators_credit.hidden-print")
      assert_html(html, "a#translations_for_page_link")
      assert_html(html, "a#translations_index_link")
      # Capitalization from actual translation string
      assert_includes(html, "Edit Translations on this Page")
      assert_includes(html, "Edit All Translations")
    end
  end

  def test_renders_both_credit_and_links_for_unofficial_language_with_tracking
    Language.track_usage
    I18n.with_locale(:fr) do
      html = render_component

      assert_html(html, "#translators_credit.hidden-print")
      # Should render both credit section and edit links
      assert_html(html, "a[class^='user_link_']")
      assert_html(html, "a#translations_for_page_link")
      assert_html(html, "a#translations_index_link")
    end
  end

  def test_renders_user_links_for_top_contributors
    I18n.with_locale(:fr) do
      html = render_component

      # Should have user links in the output
      assert_html(html, "a[class^='user_link_']")
      # Verify we have multiple contributor links
      doc = Nokogiri::HTML(html)
      user_links = doc.css("a[class^='user_link_']")
      assert(user_links.length > 1, "Should render multiple contributor links")
    end
  end

  def test_shows_and_others_when_five_contributors
    I18n.with_locale(:fr) do
      # Stub Language.find_by to return a lang with mocked top_contributors
      lang = languages(:french)
      contributors = [
        [users(:rolf).id, users(:rolf).login],
        [users(:mary).id, users(:mary).login],
        [users(:dick).id, users(:dick).login],
        [users(:katrina).id, users(:katrina).login],
        [users(:roy).id, users(:roy).login]
      ]
      lang.define_singleton_method(:top_contributors) { |_num| contributors }
      Language.stub(:find_by, lang) do
        html = render_component
        # Should render all 5 user links
        doc = Nokogiri::HTML(html)
        user_links = doc.css("a[class^='user_link_']")
        assert_equal(5, user_links.length, "Should render exactly 5 user links")
        # Should include "and others" text
        # (translation key :app_translators_credit_and_others)
        # Text varies by locale but structure is consistent
        assert_match(/and others|et autres/, html)
      end
    end
  end

  def test_does_not_show_and_others_when_fewer_than_five_contributors
    I18n.with_locale(:fr) do
      html = render_component

      # Should not include "and others" text when < 5 contributors
      assert_no_match(/and others|et autres/, html)
    end
  end

  private

  def render_component
    render(Components::TranslatorsCredit.new)
  end
end
