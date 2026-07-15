# frozen_string_literal: true

# Resolves MO's own ("mo:" namespaced) translations directly against the
# TranslationString/Language tables on a cache miss, then populates the
# cache backend so the next lookup for the same tag hits it directly
# (self-healing). This is what makes it safe to stop regenerating
# config/locales/*.yml on every deploy/edit (#4807): a cold or freshly
# cleared cache never breaks the site, it just costs one DB query per
# tag until the cache warms back up.
#
# Chained AFTER I18n::Backend::SolidCacheKeyValue (see
# config/initializers/i18n_backend.rb) -- Chain checks backends in
# order and only reaches this one on a cache miss. Ignores any key
# outside MO's own namespace (config.locale_namespace,
# "mo") so gem-provided translations (ActiveRecord/ActiveModel/etc, still
# file-loaded via a third Chain backend) aren't shadowed or queried here.
class I18n::Backend::DbFallback
  include I18n::Backend::Base
  include I18n::Backend::Flatten

  NAMESPACE_PREFIX = "#{MO.locale_namespace}.".freeze

  def initialize(cache_backend)
    @cache_backend = cache_backend
  end

  def available_locales
    Language.pluck(:locale).map(&:to_sym)
  end

  # Chain only ever calls store_translations on backends.first (the cache
  # backend) -- this exists so DbFallback satisfies Base's interface, and
  # so #lookup below can reuse it to populate the cache on a DB hit.
  def store_translations(locale, data, options = I18n::EMPTY_HASH)
    @cache_backend.store_translations(locale, data, options)
  end

  protected

  def lookup(locale, key, scope = [], options = I18n::EMPTY_HASH)
    flat_key = normalize_flat_keys(locale, key, scope, options[:separator])
    return nil unless flat_key.start_with?(NAMESPACE_PREFIX)

    tag = flat_key.delete_prefix(NAMESPACE_PREFIX)
    text = text_for(locale, tag)
    return nil unless text

    store_translations(locale,
                       { MO.locale_namespace.to_sym => { tag.to_sym => text } })
    text
  end

  private

  # Falls back to the official (English) locale's text when this locale
  # has no override of its own -- matches the fallback merge
  # LanguageExporter has always baked into every locale's regenerated
  # files (see Language#localization_strings/merge_localization_strings_into).
  def text_for(locale, tag)
    language = Language.for_locale(locale)
    return nil unless language

    str = language.translation_strings.find_by(tag: tag)
    str ||= official_language.translation_strings.find_by(tag: tag) unless
      language.official
    str&.text
  end

  # Memoized on this DbFallback instance (one per process, built once
  # at boot -- see config/initializers/i18n_backend.rb) rather than on
  # Language itself: most non-English lookups hit this fallback on a
  # cold cache, so an unmemoized query here is an avoidable repeat on
  # every one of them. `||=` already skips memoizing nil, same
  # reasoning as Language.for_locale -- if this fires before the
  # `languages` table is populated, it keeps retrying instead of
  # caching the miss forever. Deliberately NOT added to Language.official
  # itself: that would hand every caller (tests included) the same
  # cached AR instance across requests/tests, and a stale cached
  # association (e.g. translation_strings) surviving a rolled-back test
  # transaction is exactly the kind of bug that memoization risks.
  def official_language
    @official_language ||= Language.official
  end
end
