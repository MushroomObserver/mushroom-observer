# frozen_string_literal: true

require("test_helper")
require("application_mailer")

class ApplicationMailerTest < UnitTestCase
  def setup
    # Disable cop; there's no block in which to limit the time zone change
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    super
  end

  def test_valid_email_address
    assert_true(ApplicationMailer.valid_email_address?("joe@schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?("joe.schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?(""))
  end

  def test_undeliverable_email
    mary.update(email: "bogus.address")
    UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "subject", message: "body"
    ).deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not have delivered an email to 'bogus.address'.")
  end

  def test_opt_out
    mary.update(no_emails: true)
    UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "subject", message: "body"
    ).deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not deliver email if recipient has opted out.")
  end
end
