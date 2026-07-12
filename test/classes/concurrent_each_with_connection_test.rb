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

  def test_each_item_runs_with_its_own_active_db_connection
    connection_ids = Concurrent::Array.new

    ConcurrentEachWithConnection.new(pool_size: 2).call([1, 2, 3]) do |_n|
      connection_ids << ActiveRecord::Base.connection.object_id
      assert(ActiveRecord::Base.connection.active?)
    end

    assert_equal(3, connection_ids.size)
  end

  def test_reraises_first_error_after_all_items_finish
    results = Concurrent::Array.new

    error = assert_raises(RuntimeError) do
      ConcurrentEachWithConnection.new(pool_size: 2).call([1, 2, 3]) do |n|
        raise("boom on #{n}") if n == 2

        results << n
      end
    end

    assert_match(/boom on 2/, error.message)
    # The other items still ran despite item 2's failure.
    assert_equal([1, 3], results.to_a.sort)
  end

  def test_processes_more_items_than_pool_size
    results = Concurrent::Array.new

    ConcurrentEachWithConnection.new(pool_size: 2).call((1..10).to_a) do |n|
      results << n
    end

    assert_equal((1..10).to_a, results.to_a.sort)
  end
end
