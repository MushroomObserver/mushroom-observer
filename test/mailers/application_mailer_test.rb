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

  # Issue #5074: `setup_user` switches I18n.locale to the recipient's
  # locale; `mo_mail`'s early return (undeliverable `to_address`) must
  # still restore it via `ensure`, or the mailer thread's I18n.locale
  # stays leaked to whatever recipient it last tried to email.
  def test_locale_restored_when_email_undeliverable
    mary.update(email: "bogus.address", locale: "pt")

    UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "subject", message: "body"
    ).deliver_now

    assert_equal(:en, I18n.locale)
  end

  # Issue #5074: WebmasterMailer/MergeRequestMailer never call
  # `setup_user` (they send to MO.webmaster_email_address, not a
  # User), so `@old_locale` used to stay nil -- ApplicationMailer's
  # `before_action` must capture it for every mailer, not just ones
  # that call `setup_user`.
  def test_locale_restored_for_mailer_without_setup_user
    I18n.locale = :pt # rubocop:disable Rails/I18nLocaleAssignment

    WebmasterMailer.build(
      sender_email: "test@example.com", message: "hi"
    ).deliver_now

    assert_equal(:pt, I18n.locale)
  end
end
