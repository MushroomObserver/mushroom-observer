# frozen_string_literal: true

require("test_helper")
require("net/smtp")

class MailDeliveryErrorLoggingTest < ActiveJob::TestCase
  def setup
    super
    @log_path = Rails.root.join("log/email-debug.log")
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
    error = Net::SMTPServerBusy.new(
      "450 Too many connections"
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

      raised = assert_raises(Net::SMTPServerBusy) do
        perform_enqueued_jobs
      end
      assert_equal(
        "450 Too many connections", raised.message
      )
    end
  end

  private

  def new_log_entries
    return "" unless File.exist?(@log_path)

    File.open(@log_path) do |f|
      f.seek(@log_offset)
      f.read
    end
  end
end
