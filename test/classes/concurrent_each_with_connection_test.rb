# frozen_string_literal: true

require("test_helper")

class ConcurrentEachWithConnectionTest < UnitTestCase
  def test_runs_block_for_every_item
    results = Concurrent::Array.new

    ConcurrentEachWithConnection.new(pool_size: 2).call([1, 2, 3]) do |n|
      results << n
    end

    assert_equal([1, 2, 3], results.to_a.sort)
  end

  def test_defaults_to_pool_size_four
    assert_equal(
      4, ConcurrentEachWithConnection.new.instance_variable_get(:@pool_size)
    )
  end

  # NOTE: this can't assert that concurrent items get *distinct*
  # connection objects. MO's transactional-fixtures test setup pins a
  # single leased connection across all threads within one test (so
  # the per-test rollback wrapper stays consistent) -- confirmed via a
  # throwaway probe: two threads calling
  # `ActiveRecord::Base.connection_pool.with_connection` inside the
  # same test always report the same connection object_id, regardless
  # of synchronization. Outside a transactional test (the real
  # lib/tasks/lang.rake usage this class exists for), `with_connection`
  # does give each thread its own connection -- that's the whole
  # point of the pool -- but this test harness can't observe it.
  def test_each_item_runs_with_an_active_db_connection
    connection_ids = Concurrent::Array.new

    ConcurrentEachWithConnection.new(pool_size: 2).call([1, 2, 3]) do |_n|
      connection_ids << ActiveRecord::Base.connection.object_id
      assert(ActiveRecord::Base.connection.active?)
    end

    assert_equal(3, connection_ids.size)
  end

  def test_reraises_the_single_error_unchanged_after_all_items_finish
    results = Concurrent::Array.new

    error = assert_raises(RuntimeError) do
      ConcurrentEachWithConnection.new(pool_size: 2).call([1, 2, 3]) do |n|
        raise("boom on #{n}") if n == 2

        results << n
      end
    end

    assert_equal("boom on 2", error.message)
    # The other items still ran despite item 2's failure.
    assert_equal([1, 3], results.to_a.sort)
  end

  def test_raises_a_combined_error_when_multiple_items_fail_differently
    error = assert_raises(RuntimeError) do
      ConcurrentEachWithConnection.new(pool_size: 4).call([1, 2, 3]) do |n|
        raise(ArgumentError.new("bad arg #{n}")) if n == 1
        raise(TypeError.new("bad type #{n}")) if n == 3
      end
    end

    assert_match(/2 errors/, error.message)
    assert_match(/ArgumentError: bad arg 1/, error.message)
    assert_match(/TypeError: bad type 3/, error.message)
  end

  def test_processes_more_items_than_pool_size
    results = Concurrent::Array.new

    ConcurrentEachWithConnection.new(pool_size: 2).call((1..10).to_a) do |n|
      results << n
    end

    assert_equal((1..10).to_a, results.to_a.sort)
  end

  def test_requires_a_block
    assert_raises(ArgumentError) do
      ConcurrentEachWithConnection.new.call([1, 2, 3])
    end
  end

  # Exercises the `ensure` around pool shutdown: if `items.each` itself
  # raises (before any work is posted), the error must still propagate
  # instead of being swallowed -- and the pool must not hang.
  def test_propagates_error_raised_while_iterating_items
    each = ConcurrentEachWithConnection.new(pool_size: 2)
    bad_items = Object.new
    def bad_items.each(&_block)
      raise("items.each blew up")
    end

    assert_raises(RuntimeError) { each.call(bad_items) { |n| n } }
  end
end
