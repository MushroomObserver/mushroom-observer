# frozen_string_literal: true

require("test_helper")

class I18n::Backend::CacheStoreAdapterTest < UnitTestCase
  def setup
    super
    @adapter = I18n::Backend::CacheStoreAdapter.new(SolidCache::Store.new)
    @key = "_cache_store_adapter_test_key_#{object_id}"
  end

  def teardown
    @adapter.delete(@key)
    super
  end

  def test_read_returns_nil_for_missing_key
    assert_nil(@adapter[@key])
  end

  def test_write_then_read_round_trips
    @adapter[@key] = "hello"

    assert_equal("hello", @adapter[@key])
  end

  def test_write_overwrites_existing_value
    @adapter[@key] = "first"
    @adapter[@key] = "second"

    assert_equal("second", @adapter[@key])
  end

  def test_delete_removes_the_key
    @adapter[@key] = "hello"

    @adapter.delete(@key)

    assert_nil(@adapter[@key])
  end
end
