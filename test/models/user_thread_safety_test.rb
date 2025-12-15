# frozen_string_literal: true

require "test_helper"

class UserThreadSafetyTest < UnitTestCase
  # This test verifies that User.current is now thread-safe
  #
  # These tests use Concurrent::CountDownLatch for deterministic synchronization
  # instead of sleep() to avoid timing-related flakiness. The latches ensure
  # that threads reach specific checkpoints before proceeding, guaranteeing
  # that race conditions are properly tested without relying on timing.

  def test_user_current_maintains_isolation_between_threads
    alice = users(:rolf)
    bob = users(:mary)

    # Store results from each thread
    results = Concurrent::Hash.new

    # Use CountDownLatch to synchronize threads for deterministic race condition
    # Both threads will set their User.current, wait for each other, then verify
    setup_latch = Concurrent::CountDownLatch.new(2)
    check_latch = Concurrent::CountDownLatch.new(2)

    # Run two threads that set different users
    threads = [
      Thread.new do
        User.current = alice
        setup_latch.count_down
        setup_latch.wait # Wait for both threads to set their User.current
        check_latch.count_down
        check_latch.wait # Ensure both threads check at the same time
        results[:thread1_user_id] = User.current&.id
        results[:thread1_expected_id] = alice.id
      end,
      Thread.new do
        User.current = bob
        setup_latch.count_down
        setup_latch.wait # Wait for both threads to set their User.current
        check_latch.count_down
        check_latch.wait # Ensure both threads check at the same time
        results[:thread2_user_id] = User.current&.id
        results[:thread2_expected_id] = bob.id
      end
    ]

    threads.each(&:join)

    # With class variables (current implementation), these will FAIL
    # because threads share the same @@user variable
    thread1_login = User.find_by(id: results[:thread1_user_id])&.login
    thread2_login = User.find_by(id: results[:thread2_user_id])&.login
    assert_equal(results[:thread1_expected_id], results[:thread1_user_id],
                 "Thread 1 should see alice, but sees #{thread1_login}")
    assert_equal(results[:thread2_expected_id], results[:thread2_user_id],
                 "Thread 2 should see bob, but sees #{thread2_login}")
  end

  def test_user_current_location_format_maintains_isolation_between_threads
    alice = users(:rolf)
    bob = users(:mary)

    # Set different location formats
    alice.location_format = "postal"
    bob.location_format = "scientific"

    results = Concurrent::Hash.new

    # Use CountDownLatch for deterministic synchronization
    setup_latch = Concurrent::CountDownLatch.new(2)
    check_latch = Concurrent::CountDownLatch.new(2)

    threads = [
      Thread.new do
        User.current = alice
        setup_latch.count_down
        setup_latch.wait # Wait for both threads to set their User.current
        check_latch.count_down
        check_latch.wait # Ensure both threads check at the same time
        results[:thread1_format] = User.current_location_format
        results[:thread1_expected] = "postal"
      end,
      Thread.new do
        User.current = bob
        setup_latch.count_down
        setup_latch.wait # Wait for both threads to set their User.current
        check_latch.count_down
        check_latch.wait # Ensure both threads check at the same time
        results[:thread2_format] = User.current_location_format
        results[:thread2_expected] = "scientific"
      end
    ]

    threads.each(&:join)

    assert_equal(results[:thread1_expected], results[:thread1_format],
                 "Thread 1 should see 'postal' format")
    assert_equal(results[:thread2_expected], results[:thread2_format],
                 "Thread 2 should see 'scientific' format")
  end
end
