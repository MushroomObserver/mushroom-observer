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

  # Regression guard for the #3589 thread-safety fix: all_users/
  # reviewers/one_user no longer memoize anything (no Rails.cache, no
  # Concurrent::Map) - they're just find_by_name against a unique
  # index on user_groups.name, which is inherently thread-safe since
  # there's no shared mutable state to race on. Proves concurrent
  # calls each get back the correct group for the id they asked for.
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
