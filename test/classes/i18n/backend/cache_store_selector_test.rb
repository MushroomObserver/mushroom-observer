# frozen_string_literal: true

require("test_helper")

class I18n::Backend::CacheStoreSelectorTest < UnitTestCase
  def test_returns_the_given_cache_when_not_a_null_store
    real_cache = ActiveSupport::Cache::MemoryStore.new

    result = I18n::Backend::CacheStoreSelector.call(rails_cache: real_cache)

    assert_same(real_cache, result)
  end

  def test_falls_back_to_a_real_solid_cache_store_for_a_null_store
    result = I18n::Backend::CacheStoreSelector.call(
      rails_cache: ActiveSupport::Cache::NullStore.new
    )

    assert_instance_of(SolidCache::Store, result)
  end

  # No arg -- exercises the real default (Rails.cache). The test
  # environment's Rails.cache IS a NullStore (config/environments/
  # test.rb), so this pins the exact behavior every other i18n-backend
  # test in this suite depends on: store_translations calls must
  # actually round-trip through a real cache, not silently no-op.
  def test_default_arg_falls_back_correctly_in_the_test_environment
    assert_instance_of(ActiveSupport::Cache::NullStore, Rails.cache,
                       "Sanity check: this test only proves anything " \
                       "if the test environment's Rails.cache is a " \
                       "NullStore in the first place")
    assert_instance_of(SolidCache::Store, I18n::Backend::CacheStoreSelector.call)
  end
end
