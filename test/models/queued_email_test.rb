# frozen_string_literal: true

require("test_helper")

class QueuedEmailTest < UnitTestCase
  def setup
    super
    QueuedEmail.queue = true
  end

  def teardown
    QueuedEmail.queue = false
  end

  def test_send_email
    email = QueuedEmail::NameProposal.new(user: rolf, to_user: mary)
    assert_not(email.send_email)
  end

  def test_dump
    name_tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
    naming = namings(:agaricus_campestris_naming)
    email = QueuedEmail::NameTracking.create_email(name_tracker, naming)
    email.send_email
    dump = QueuedEmail.last.dump
    assert_match(/name_tracker/i, dump)
    assert_match(/naming/i, dump)
    assert_match(/rolf/i, dump)
    assert_match(/mary/i, dump)
  end

  def test_send_email_exception
    raises_exception = -> { raise(RuntimeError.new) }
    email = QueuedEmail::NameProposal.new(user: rolf, to_user: mary)
    email.stub(:deliver_email, raises_exception) do
      original_stderr = $stderr.clone
      $stderr.reopen(File.new(File::NULL, "w"))
      assert_not(email.send_email)
      $stderr.reopen(original_stderr)
    end
  end

  # test_verify_account_with_user removed - migrated to deliver_later
  # The VerifyAccount email no longer uses QueuedEmail, so there's nothing
  # to test here. The new implementation uses VerifyAccountMailer.deliver_later.
end
