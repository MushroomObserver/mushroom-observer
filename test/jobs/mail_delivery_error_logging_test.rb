# frozen_string_literal: true

require("test_helper")
require("net/smtp")

class MailDeliveryErrorLoggingTest < ActiveJob::TestCase
  def setup
    super
    @log_path = Rails.root.join("log/email-debug.log")
    @log_existed = File.exist?(@log_path)
    @original_content =
      @log_existed ? File.read(@log_path) : ""
  end

  def teardown
    if @log_existed
      File.write(@log_path, @original_content)
    elsif File.exist?(@log_path)
      File.delete(@log_path)
    end
    super
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

    log_entries = File.read(@log_path)
    new_entries = log_entries.sub(@original_content, "")
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

    log_entries = File.read(@log_path)
    new_entries = log_entries.sub(@original_content, "")
    assert_empty(
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
end
