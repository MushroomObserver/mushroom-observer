# frozen_string_literal: true

require("test_helper")

# Proves the actual bug fixed in #4811's review: the real, wired-up
# I18n.backend (config/initializers/i18n_backend.rb) must (1) never sit
# on a no-op cache store, and (2) actually serve a warm lookup from that
# cache instead of re-querying TranslationString every time -- which is
# what made SolidCache::Store.new (reaching around Rails.cache and its
# environment-specific config.cache_store override) cost a real SQL
# query on every single translation lookup, cache hit or not.
class CacheWiringTest < UnitTestCase
  def setup
    super
    @tag = :"_cache_wiring_test_tag_#{object_id}"
    Language.official.translation_strings.create!(
      tag: @tag, text: "cache wiring test value", user: User.admin
    )
  end

  def teardown
    TranslationString.where(tag: @tag).destroy_all
    I18n.backend.backends.first.delete_translation(:en, @tag)
    super
  end

  def test_cache_backend_is_never_a_no_op_store
    raw_store = I18n.backend.backends.first.store.store

    assert_not_instance_of(
      ActiveSupport::Cache::NullStore, raw_store,
      "I18n's cache backend must never be a no-op store -- every " \
      "I18n.t/.l call goes through it, unlike a disposable fragment cache"
    )
  end

  def test_cold_lookup_queries_translation_strings
    queries = translation_string_query_count do
      I18n.t("mo.#{@tag}", locale: :en)
    end

    assert_operator(queries, :>=, 1,
                    "a cold (never-looked-up) tag must consult " \
                    "TranslationString via DbFallback")
  end

  def test_warm_lookup_does_not_requery_translation_strings
    I18n.t("mo.#{@tag}", locale: :en) # cold lookup -- warms the cache

    result = nil
    queries = translation_string_query_count do
      result = I18n.t("mo.#{@tag}", locale: :en)
    end

    assert_equal("cache wiring test value", result)
    assert_equal(0, queries,
                 "a warm lookup must be served from the cache backend, " \
                 "not re-query TranslationString")
  end

  private

  def translation_string_query_count(&block)
    count = 0
    callback = lambda do |*, payload|
      count += 1 if payload[:sql].include?("translation_strings")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record",
                                            &block)
    count
  end
end
