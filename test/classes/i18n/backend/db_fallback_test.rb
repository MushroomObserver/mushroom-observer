# frozen_string_literal: true

require("test_helper")

class I18n::Backend::DbFallbackTest < UnitTestCase
  def setup
    super
    @cache_calls = []
    calls = @cache_calls
    @fake_cache = Object.new
    @fake_cache.define_singleton_method(:store_translations) do |*args|
      calls << args
    end
    @backend = I18n::Backend::DbFallback.new(@fake_cache)
  end

  def test_lookup_returns_official_locale_text
    assert_equal("one", @backend.send(:lookup, :en, "mo.one", [], {}))
  end

  def test_lookup_uses_locale_specific_override_when_present
    assert_equal("ένα", @backend.send(:lookup, :el, "mo.one", [], {}))
  end

  # Greek has no override for "three" -- only English (official) does.
  # Matches the fallback merge Language::Exporter has always baked into
  # every locale's regenerated files.
  def test_lookup_falls_back_to_official_when_locale_lacks_override
    assert_equal("three", @backend.send(:lookup, :el, "mo.three", [], {}))
  end

  def test_lookup_returns_nil_for_unknown_tag
    assert_nil(
      @backend.send(:lookup, :en, "mo.this_tag_does_not_exist_xyz", [], {})
    )
  end

  def test_lookup_returns_nil_for_unknown_locale
    assert_nil(@backend.send(:lookup, :xx, "mo.one", [], {}))
  end

  # Gem-provided keys (ActiveRecord/ActiveModel/etc) are not this
  # backend's concern -- GemFileBackend (Chain's third backend) handles
  # them. Must return nil rather than mis-querying TranslationString
  # with a garbage "tag".
  def test_lookup_returns_nil_for_non_mo_namespace
    assert_nil(
      @backend.send(:lookup, :en, "activerecord.errors.messages.blank",
                    [], {})
    )
  end

  def test_lookup_populates_cache_on_hit
    @backend.send(:lookup, :en, "mo.one", [], {})

    assert_equal(1, @cache_calls.size)
    locale, data, = @cache_calls.first
    assert_equal(:en, locale)
    assert_equal({ mo: { one: "one" } }, data)
  end

  def test_lookup_does_not_populate_cache_on_miss
    @backend.send(:lookup, :en, "mo.this_tag_does_not_exist_xyz", [], {})

    assert_empty(@cache_calls)
  end

  def test_available_locales
    assert_equal(Language.pluck(:locale).map(&:to_sym).sort,
                 @backend.available_locales.sort)
  end

  def test_store_translations_delegates_to_cache_backend
    @backend.store_translations(:en, { mo: { foo: "bar" } })

    assert_equal([[:en, { mo: { foo: "bar" } }, {}]], @cache_calls)
  end
end
