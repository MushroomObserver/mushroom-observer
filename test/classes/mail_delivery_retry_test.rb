# frozen_string_literal: true

require("test_helper")

class MailDeliveryRetryTest < UnitTestCase
  def test_transient_errors
    [
      Net::ReadTimeout.new,
      EOFError.new,
      Net::SMTPServerBusy.new("421-4.4.5 Server busy, try again later."),
      Net::SMTPAuthenticationError.new(
        "454-4.7.0 Cannot authenticate due to temporary system problem."
      )
    ].each do |error|
      assert_true(MailDeliveryRetry.transient?(error), error.inspect)
    end
  end

  def test_permanent_errors
    [
      Net::SMTPAuthenticationError.new("535-5.7.8 Username and Password " \
                                       "not accepted."),
      Net::SMTPFatalError.new("550 No such user"),
      StandardError.new("view failed to render")
    ].each do |error|
      assert_not(MailDeliveryRetry.transient?(error), error.inspect)
    end
  end

  def test_waits_run_out_after_five_attempts
    error = Net::ReadTimeout.new

    assert_equal(MailDeliveryRetry::WAITS,
                 (1..4).map { |n| MailDeliveryRetry.wait_for(error, n) })
    assert_nil(MailDeliveryRetry.wait_for(error, 5))
    assert_nil(MailDeliveryRetry.wait_for(StandardError.new, 1))
  end
end
