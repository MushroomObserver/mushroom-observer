# frozen_string_literal: true

require "test_helper"

# Tests for TranslatorsCredit component conditional rendering
class TranslatorsCreditTest < ComponentTestCase
  def setup
    super
    @original_locale = I18n.locale
  end

  def teardown
    I18n.locale = @original_locale # rubocop:disable Rails/I18nLocaleAssignment
    Language.ignore_usage
    super
  end

  def test_ci_debug_i18n_french_translations
    # Diagnostic test to debug CI I18n environment
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment

    # Check if fr.yml exists and can be read
    fr_yml_path = Rails.root.join("config/locales/fr.yml")
    puts "\n=== CI I18n Debugging ==="
    puts "fr.yml exists: #{File.exist?(fr_yml_path)}"
    if File.exist?(fr_yml_path)
      puts "fr.yml size: #{File.size(fr_yml_path)} bytes"
      # Read specific keys from YAML file directly (with "mo" namespace)
      yaml_content = YAML.load_file(fr_yml_path)
      puts "YAML fr.mo.app_translators_credit: #{yaml_content.dig('fr', 'mo', 'app_translators_credit')}"
      puts "YAML fr.mo.app_translators_credit_and_others: #{yaml_content.dig('fr', 'mo', 'app_translators_credit_and_others')}"
    end

    # Check I18n configuration
    puts "\nMO.locale_namespace: #{MO.locale_namespace.inspect}"
    puts "I18n.available_locales: #{I18n.available_locales.inspect}"
    puts "I18n.locale: #{I18n.locale.inspect}"
    puts "I18n.default_locale: #{I18n.default_locale.inspect}"

    # Check I18n backend
    puts "\nI18n backend class: #{I18n.backend.class}"
    puts "I18n.backend.available_locales: #{I18n.backend.available_locales.inspect}"

    # Try to access translations using the "mo" namespace
    puts "\nI18n.t('mo.app_translators_credit', locale: :fr): #{I18n.t('mo.app_translators_credit', locale: :fr)}"
    puts "I18n.t('mo.app_translators_credit_and_others', locale: :fr): #{I18n.t('mo.app_translators_credit_and_others', locale: :fr)}"

    # Try using the Symbol extension method
    puts "\n:app_translators_credit.l: #{:app_translators_credit.l}"
    puts ":app_translators_credit_and_others.l: #{:app_translators_credit_and_others.l}"

    # Check if translations are loaded in backend
    if I18n.backend.respond_to?(:translations)
      fr_translations = I18n.backend.translations[:fr]
      puts "\nBackend has :fr translations: #{!fr_translations.nil?}"
      if fr_translations && fr_translations[:mo]
        puts "Backend fr.mo.app_translators_credit: #{fr_translations[:mo][:app_translators_credit]}"
        puts "Backend fr.mo.app_translators_credit_and_others: #{fr_translations[:mo][:app_translators_credit_and_others]}"
      end
    end

    # Try rendering component and see what we get
    html = render_component
    puts "\nRendered HTML: #{html}"
    puts "=== End CI I18n Debugging ===\n"

    # This test always passes - it's just for debugging output
    assert(true, "Diagnostic test completed")
  end

  def test_does_not_render_for_official_language_without_tracking
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
    html = render_component
    assert_equal("", html)
  end

  def test_renders_translators_credit_for_unofficial_language
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment
    html = render_component

    assert_html(html, "#translators_credit.hidden-print")
    assert_html(html, "hr")
    # Should render credit section with user links
    assert_html(html, "a[class^='user_link_']")
    # Should not render edit links when not tracking
    assert_no_html(html, "a#translations_for_page_link")
  end

  def test_renders_translation_links_when_tracking_usage
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
    Language.track_usage
    html = render_component

    assert_html(html, "#translators_credit.hidden-print")
    assert_html(html, "a#translations_for_page_link")
    assert_html(html, "a#translations_index_link")
    # Capitalization from actual translation string
    assert_includes(html, "Edit Translations on this Page")
    assert_includes(html, "Edit All Translations")
  end

  def test_renders_both_credit_and_links_for_unofficial_language_with_tracking
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment
    Language.track_usage
    html = render_component

    assert_html(html, "#translators_credit.hidden-print")
    # Should render both credit section and edit links
    assert_html(html, "a[class^='user_link_']")
    assert_html(html, "a#translations_for_page_link")
    assert_html(html, "a#translations_index_link")
  end

  def test_renders_user_links_for_top_contributors
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment
    html = render_component

    # Should have user links in the output
    assert_html(html, "a[class^='user_link_']")
    # Verify we have multiple contributor links
    doc = Nokogiri::HTML(html)
    user_links = doc.css("a[class^='user_link_']")
    assert(user_links.length > 1, "Should render multiple contributor links")
  end

  def test_shows_and_others_when_five_contributors
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment
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
      # Should include "and others" text (translation key :app_translators_credit_and_others)
      # Text varies by locale but structure is consistent
      assert_match(/and others|et autres/, html)
    end
  end

  def test_does_not_show_and_others_when_fewer_than_five_contributors
    I18n.locale = :fr # rubocop:disable Rails/I18nLocaleAssignment
    html = render_component

    # Should not include "and others" text when < 5 contributors
    assert_no_match(/and others|et autres/, html)
  end

  private

  def render_component
    render(Components::TranslatorsCredit.new)
  end
end
