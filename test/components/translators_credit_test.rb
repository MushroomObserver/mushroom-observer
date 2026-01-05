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
      # Text is in French when locale is :fr
      assert_includes(html, "Traduit en français par")
    end
  end

  def test_renders_translation_links_when_tracking_usage
    I18n.with_locale(:en) do
      Language.track_usage
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
    I18n.with_locale(:fr) do
      Language.track_usage
      html = render_component

      assert_html(html, "#translators_credit.hidden-print")
      # Text is in French
      assert_includes(html, "Traduit en français par")
      assert_html(html, "a#translations_for_page_link")
      assert_html(html, "a#translations_index_link")
    end
  end

  def test_renders_user_links_for_top_contributors
    I18n.with_locale(:fr) do
      html = render_component

      # Should have user links in the output (from translation_strings)
      assert_html(html, "a[class^='user_link_']")
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
        # Text is in French: "et autres"
        assert_includes(html, "et autres")
      end
    end
  end

  def test_does_not_show_and_others_when_fewer_than_five_contributors
    I18n.with_locale(:fr) do
      # The actual French language fixture likely has fewer than 5 contributors
      html = render_component

      assert_no_match(/et autres/, html)
    end
  end

  private

  def render_component
    render(Components::TranslatorsCredit.new)
  end
end
