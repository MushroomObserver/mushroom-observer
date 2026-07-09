# frozen_string_literal: true

require("test_helper")

class UserGroupTest < UnitTestCase
  def test_all_users
    group = UserGroup.all_users
    assert_equal("all users", group.name)
  end

  def test_reviewers
    group = UserGroup.reviewers
    assert_equal("reviewers", group.name)
  end

  def test_one_user
    rolf = users(:rolf)
    group = UserGroup.one_user(rolf)
    assert_equal("user #{rolf.id}", group.name)

    # Also accepts a raw id.
    assert_equal(group, UserGroup.one_user(rolf.id))
  end

  # Proves UserGroup.one_user's per-id cache (a Concurrent::Map) is
  # thread-safe: N threads concurrently request several different
  # users' meta-groups, each asserting it got back the correct group
  # for the id it asked for - not another thread's. A bare
  # `hash[id] ||= find_by_name(...)` is not atomic across threads;
  # Concurrent::Map#fetch_or_store guarantees the block runs at most
  # once per key regardless of concurrent callers.
  def test_thread_safety_of_one_user_cache
    UserGroup.clear_cache_for_unit_tests
    user_fixtures = [:rolf, :mary, :dick, :katrina]
    results = Queue.new
    barrier = Concurrent::CyclicBarrier.new(user_fixtures.size * 3)

    threads = (user_fixtures * 3).map do |fixture_name|
      Thread.new do
        user = users(fixture_name)
        barrier.wait
        group = UserGroup.one_user(user)
        results << [user.id, group]
      end
    end
    threads.each(&:join)

    until results.empty?
      user_id, group = results.pop
      assert_equal("user #{user_id}", group.name,
                   "UserGroup.one_user(#{user_id}) returned a mismatched " \
                   "group - one_user's cache is not thread-safe")
    end
  end
end
