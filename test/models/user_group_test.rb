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

  # all_users/reviewers/one_user memoize per request (Thread.current[...],
  # not a class ivar/Rails.cache) -- these are called many times within a
  # single request (once per description in a name/location's reader/
  # writer/admin-group listing), so a plain indexed find_by_name per call
  # is still wasted work within that one request, even though the index
  # alone makes each call cheap. Proves a 2nd call doesn't re-query.
  def test_all_users_memoized_within_a_request
    calls = 0
    UserGroup.stub(:find_by_name, lambda { |name|
      calls += 1
      UserGroup.find_by(name: name)
    }) do
      first = UserGroup.all_users
      second = UserGroup.all_users
      assert_equal(first, second)
    end
    assert_equal(1, calls)
  end

  def test_reviewers_memoized_within_a_request
    calls = 0
    UserGroup.stub(:find_by_name, lambda { |name|
      calls += 1
      UserGroup.find_by(name: name)
    }) do
      UserGroup.reviewers
      UserGroup.reviewers
    end
    assert_equal(1, calls)
  end

  def test_one_user_memoized_per_id_within_a_request
    rolf = users(:rolf)
    mary = users(:mary)
    calls = Hash.new(0)
    UserGroup.stub(:find_by_name, lambda { |name|
      calls[name] += 1
      UserGroup.find_by(name: name)
    }) do
      UserGroup.one_user(rolf)
      UserGroup.one_user(rolf)
      UserGroup.one_user(mary)
    end
    assert_equal(1, calls["user #{rolf.id}"])
    assert_equal(1, calls["user #{mary.id}"])
  end

  # Regression guard for the #3589 landmine pattern (see Textile's
  # per-request reset, #4741): the memo above is Thread.current-scoped,
  # so it must be cleared once per request -- otherwise a request that
  # never calls these would still see stale groups left behind by
  # whatever request ran on this same pooled thread before it.
  def test_reset_request_cache_clears_all_three_memos
    UserGroup.all_users
    UserGroup.reviewers
    UserGroup.one_user(users(:rolf))

    UserGroup.reset_request_cache

    calls = 0
    UserGroup.stub(:find_by_name, lambda { |name|
      calls += 1
      UserGroup.find_by(name: name)
    }) do
      UserGroup.all_users
      UserGroup.reviewers
      UserGroup.one_user(users(:rolf))
    end
    assert_equal(3, calls,
                 "reset_request_cache should clear all_users, reviewers, " \
                 "and one_user's memo")
  end

  # Regression guard for the #3589 thread-safety fix: even with a
  # per-request memo, concurrent calls on separate threads must never
  # cross-contaminate -- each thread's Thread.current is independent.
  # Proves concurrent calls each get back the correct group for the id
  # they asked for.
  def test_concurrent_one_user_calls_return_correct_groups
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
    threads.each(&:value)

    until results.empty?
      user_id, group = results.pop
      assert_equal("user #{user_id}", group.name,
                   "UserGroup.one_user(#{user_id}) returned a mismatched " \
                   "group")
    end
  end
end
