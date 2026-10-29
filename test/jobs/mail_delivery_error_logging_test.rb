# frozen_string_literal: true

require("test_helper")
require("net/smtp")

class MailDeliveryErrorLoggingTest < ActiveJob::TestCase
  def setup
    super
    # Per-worker path so parallel workers don't pollute each other's
    # offset-based log delta. See MO.email_debug_log_path.
    @log_path = MO.email_debug_log_path
    @log_offset = File.exist?(@log_path) ? File.size(@log_path) : 0
  end

  def test_mail_delivery_failure_logged_to_email_debug_log
    error = Net::SMTPAuthenticationError.new(
      "535 Authentication failed"
    )

    UserQuestionMailer.stub(
      :deliver_mail, ->(_mail) { raise(error) }
    ) do
      UserQuestionMailer.build(
        sender: users(:rolf),
        receiver: users(:mary),
        subject: "test",
        message: "body"
      ).deliver_later

      assert_raises(Net::SMTPAuthenticationError) do
        perform_enqueued_jobs
      end
    end

    new_entries = new_log_entries
    assert_match(/DELIVERY FAILED/, new_entries)
    assert_match(/UserQuestionMailer/, new_entries)
    assert_match(/Net::SMTPAuthenticationError/, new_entries)
    assert_match(/Authentication failed/, new_entries)
  end

  def test_non_mail_job_failure_not_logged
    job = Class.new(ApplicationJob) do
      self.queue_adapter = :test

      def perform
        raise(StandardError.new("test error"))
      end
    end

    assert_raises(StandardError) do
      job.perform_now
    end

    new_entries = new_log_entries
    assert_no_match(
      /DELIVERY FAILED/,
      new_entries,
      "Non-mail job errors should not be logged " \
      "to email-debug.log"
    )
  end

  def test_mail_delivery_failure_re_raises_exception
    error = Net::SMTPFatalError.new("550 No such user")

    UserQuestionMailer.stub(
      :deliver_mail, ->(_mail) { raise(error) }
    ) do
      enqueue_user_question

      raised = assert_raises(Net::SMTPFatalError) do
        perform_enqueued_jobs
      end
      assert_equal("550 No such user", raised.message)
    end
  end

  # A Gmail stall: the first attempt times out, the retry goes through.
  def test_transient_failure_is_retried
    calls = 0
    flaky = lambda do |_mail|
      calls += 1
      raise(Net::ReadTimeout.new) if calls == 1
    end

    UserQuestionMailer.stub(:deliver_mail, flaky) do
      enqueue_user_question
      perform_enqueued_jobs
      assert_enqueued_jobs(1)
      perform_enqueued_jobs
    end

    assert_equal(2, calls)
    assert_no_enqueued_jobs
    assert_match(/DELIVERY RETRY in 1 minute UserQuestionMailer/,
                 new_log_entries)
    assert_no_match(/DELIVERY FAILED/, new_log_entries)
  end

  def test_transient_failure_gives_up_after_five_attempts
    calls = 0
    busy = lambda do |_mail|
      calls += 1
      raise(Net::SMTPServerBusy.new("421-4.4.5 Server busy"))
    end

    UserQuestionMailer.stub(:deliver_mail, busy) do
      enqueue_user_question
      assert_raises(Net::SMTPServerBusy) do
        5.times { perform_enqueued_jobs }
      end
    end

    assert_equal(5, calls)
    assert_equal(4, new_log_entries.scan("DELIVERY RETRY").size)
    assert_match(/DELIVERY FAILED UserQuestionMailer/, new_log_entries)
  end

  private

  def enqueue_user_question
    UserQuestionMailer.build(
      sender: users(:rolf), receiver: users(:mary),
      subject: "test", message: "body"
    ).deliver_later
  end

  def new_log_entries
    return "" unless File.exist?(@log_path)

    # If another parallel worker truncated the log (via clear_logs),
    # the file may be smaller than our saved offset. Reset to read
    # from the beginning in that case.
    @log_offset = 0 if File.size(@log_path) < @log_offset

    File.open(@log_path) do |f|
      f.seek(@log_offset)
      f.read
    end
  end
end
