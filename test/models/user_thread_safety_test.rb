# frozen_string_literal: true

require "test_helper"

class UserThreadSafetyTest < UnitTestCase
  # This test verifies that User.current is NOT thread-safe with class variables
  # It should FAIL with the current implementation
  # It should PASS after converting to Thread.current

  test "User.current maintains isolation between threads" do
    alice = users(:rolf)
    bob = users(:mary)

    # Store results from each thread
    results = Concurrent::Hash.new

    # Run two threads that set different users
    threads = [
      Thread.new do
        User.current = alice
        sleep(0.05) # Give time for race condition to occur
        results[:thread1_user_id] = User.current&.id
        results[:thread1_expected_id] = alice.id
      end,
      Thread.new do
        sleep(0.01) # Start slightly after first thread
        User.current = bob
        sleep(0.05)
        results[:thread2_user_id] = User.current&.id
        results[:thread2_expected_id] = bob.id
      end
    ]

    threads.each(&:join)

    # With class variables (current implementation), these will FAIL
    # because threads share the same @@user variable
    thread1_login = User.find_by(id: results[:thread1_user_id])&.login
    thread2_login = User.find_by(id: results[:thread2_user_id])&.login
    assert_equal results[:thread1_expected_id], results[:thread1_user_id],
                 "Thread 1 should see alice, but sees #{thread1_login}"
    assert_equal results[:thread2_expected_id], results[:thread2_user_id],
                 "Thread 2 should see bob, but sees #{thread2_login}"
  end

  test "User.current_location_format maintains isolation between threads" do
    alice = users(:rolf)
    bob = users(:mary)

    # Set different location formats
    alice.location_format = "postal"
    bob.location_format = "scientific"

    results = Concurrent::Hash.new

    threads = [
      Thread.new do
        User.current = alice
        sleep(0.05)
        results[:thread1_format] = User.current_location_format
        results[:thread1_expected] = "postal"
      end,
      Thread.new do
        sleep(0.01)
        User.current = bob
        sleep(0.05)
        results[:thread2_format] = User.current_location_format
        results[:thread2_expected] = "scientific"
      end
    ]

    threads.each(&:join)

    assert_equal results[:thread1_expected], results[:thread1_format],
                 "Thread 1 should see 'postal' format"
    assert_equal results[:thread2_expected], results[:thread2_format],
                 "Thread 2 should see 'scientific' format"
  end
end
