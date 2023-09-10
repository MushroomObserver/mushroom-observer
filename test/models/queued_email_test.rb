# frozen_string_literal: true

require("test_helper")

class QueuedEmailTest < UnitTestCase
  def test_send_email
    email = QueuedEmail::NameChange.new(user: rolf, to_user: mary)
    assert_not(email.send_email)
  end

  def test_dump
    subject = "Supercalifragilistic"
    note = "Phantasmagorical observations"
    email = QueuedEmail::UserQuestion.create_email(rolf, mary, subject, note)
    email.send_email
    dump = QueuedEmail.last.dump
    assert_match(/supercalifragilistic/i, dump)
    assert_match(/phantasmagorical/i, dump)
    assert_match(/rolf/i, dump)
    assert_match(/mary/i, dump)
  end

  def test_send_email_exception
    raises_exception = -> { raise(RuntimeError.new) }
    email = QueuedEmail::NameChange.new(user: rolf, to_user: mary)
    email.stub(:deliver_email, raises_exception) do
      original_stderr = $stderr.clone
      $stderr.reopen(File.new("/dev/null", "w"))
      assert_not(email.send_email)
      $stderr.reopen(original_stderr)
    end
  end

  def test_verify_account_with_user
    # User.current should always be nil when the VerifyAccount email is
    # created, so this should never happen, but somehow *has* happened multiple
    # times in the wild.  It's worth testing.
    User.current = @dick
    QueuedEmail::VerifyAccount.create_email(@dick)
    email = QueuedEmail.last
    assert_nil(email.user)
  end
end
