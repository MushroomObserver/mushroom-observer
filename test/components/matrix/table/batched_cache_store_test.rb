# frozen_string_literal: true

require "test_helper"

# BatchedCacheStore#fetch is a custom cache-store method (matching
# Rails.cache's fetch(key) { block } interface), not Hash/Array#fetch
# -- Style/RedundantFetchBlock doesn't know that and "corrects" these
# calls into fetch(key, value), which doesn't even match this class's
# signature (raises ArgumentError). Disabled for the whole file since
# nearly every test calls #fetch.
# rubocop:disable Style/RedundantFetchBlock
class Components::Matrix::Table::BatchedCacheStoreTest < UnitTestCase
  # Wraps a real store, counting calls so tests can assert the batched
  # store issues exactly one read_multi/write_multi regardless of how
  # many individual keys are involved -- the whole point of this class.
  class CallCountingStore
    attr_reader :read_multi_calls, :write_multi_calls

    def initialize(real_store)
      @real_store = real_store
      @read_multi_calls = 0
      @write_multi_calls = 0
    end

    def read_multi(*keys)
      @read_multi_calls += 1
      @real_store.read_multi(*keys)
    end

    def write_multi(hash)
      @write_multi_calls += 1
      @real_store.write_multi(hash)
    end

    delegate :read, to: :@real_store
  end

  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
  end

  def test_fetch_serves_a_prefetched_hit_without_calling_the_block
    @store.write("a", "cached_a")
    batched = Components::Matrix::Table::BatchedCacheStore.new(@store, ["a"])

    computed = false
    result = batched.fetch("a") do
      computed = true
      "fresh_a"
    end

    assert_equal("cached_a", result)
    assert_not(computed, "block must not run for a prefetched hit")
  end

  def test_fetch_computes_and_returns_the_value_for_a_miss
    batched = Components::Matrix::Table::BatchedCacheStore.new(@store, ["a"])

    result = batched.fetch("a") { "fresh_a" }

    assert_equal("fresh_a", result)
  end

  def test_a_miss_is_not_written_until_flush_writes
    batched = Components::Matrix::Table::BatchedCacheStore.new(@store, ["a"])
    batched.fetch("a") { "fresh_a" }

    assert_nil(@store.read("a"))
  end

  def test_flush_writes_persists_every_pending_miss
    batched = Components::Matrix::Table::BatchedCacheStore.new(
      @store, %w[a b]
    )
    batched.fetch("a") { "fresh_a" }
    batched.fetch("b") { "fresh_b" }
    batched.flush_writes!

    assert_equal("fresh_a", @store.read("a"))
    assert_equal("fresh_b", @store.read("b"))
  end

  def test_flush_writes_does_not_touch_the_store_when_nothing_is_pending
    spy = CallCountingStore.new(@store)
    @store.write("a", "cached_a")
    batched = Components::Matrix::Table::BatchedCacheStore.new(spy, ["a"])
    batched.fetch("a") { "unused" } # hit, nothing queued
    batched.flush_writes!

    assert_equal(0, spy.write_multi_calls)
  end

  def test_a_mix_of_hits_and_misses_resolves_each_correctly
    @store.write("a", "cached_a")
    batched = Components::Matrix::Table::BatchedCacheStore.new(
      @store, %w[a b]
    )

    a_computed = false
    b_computed = false
    a_result = batched.fetch("a") do
      a_computed = true
      "fresh_a"
    end
    b_result = batched.fetch("b") do
      b_computed = true
      "fresh_b"
    end

    assert_equal("cached_a", a_result)
    assert_not(a_computed, "a was prefetched, block must not run")
    assert_equal("fresh_b", b_result)
    assert(b_computed, "b was a genuine miss, block must run")
  end

  def test_read_multi_and_write_multi_are_each_called_exactly_once
    spy = CallCountingStore.new(@store)
    batched = Components::Matrix::Table::BatchedCacheStore.new(
      spy, %w[a b c]
    )
    batched.fetch("a") { "x" }
    batched.fetch("b") { "y" }
    batched.fetch("c") { "z" }
    batched.flush_writes!

    assert_equal(1, spy.read_multi_calls)
    assert_equal(1, spy.write_multi_calls)
  end

  def test_empty_keys_skips_read_multi_entirely
    spy = CallCountingStore.new(@store)
    batched = Components::Matrix::Table::BatchedCacheStore.new(spy, [])

    result = batched.fetch("a") { "computed" }

    assert_equal("computed", result)
    assert_equal(0, spy.read_multi_calls)
  end
end
# rubocop:enable Style/RedundantFetchBlock
