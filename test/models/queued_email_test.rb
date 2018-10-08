require "test_helper"

class QueuedEmailTest < UnitTestCase
  def test_send_email
    email = QueuedEmail::NameChange.new({user: rolf, to_user: mary})
    assert !email.send_email
  end

  def test_send_email_no_to_from 
    email = QueuedEmail.new()
    assert !email.send_email
  end

  def test_send_email_exception
    raises_exception = -> { raise RuntimeError.new }
    email = QueuedEmail::NameChange.new({user: rolf, to_user: mary})
    email.stub :deliver_email, raises_exception do
      original_stderr = $stderr.clone
      $stderr.reopen(File.new('/dev/null', 'w'))
      assert !email.send_email
      $stderr.reopen(original_stderr)
    end
  end
end
