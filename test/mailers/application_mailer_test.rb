# frozen_string_literal: true

require("test_helper")

class ApplicationMailerTest < UnitTestCase
  def setup
    # Disable cop; there's no block in which to limit the time zone change
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    super
  end

  # Development's :file delivery. A mailer with a Gmail account
  # (news_delivery) used to replace the file settings, losing the mail.
  def test_file_delivery_writes_mail_for_gmail_account_mailers
    Dir.mktmpdir do |dir|
      ActionMailer::Base.delivery_method = :file
      ActionMailer::Base.file_settings = { location: dir }
      ActionMailer::Base.raise_delivery_errors = true

      UserQuestionMailer.build(
        sender: rolf, receiver: mary, subject: "subject", message: "body"
      ).deliver_now

      assert_path_exists(File.join(dir, mary.email))
    ensure
      ActionMailer::Base.delivery_method = :test
    end
  end

  def test_smtp_delivery_uses_the_gmail_account
    news = { address: "smtp.example.com", port: 587 }
    ActionMailer::Base.delivery_method = :smtp
    Rails.application.credentials.stub(:gmail_smtp_settings_news, news) do
      mail = UserQuestionMailer.build(
        sender: rolf, receiver: mary, subject: "subject", message: "body"
      ).message

      assert_equal(news, mail.delivery_method.settings)
    end
  ensure
    ActionMailer::Base.delivery_method = :test
  end

  def test_every_mailer_picks_a_gmail_account
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/mailers").to_s)
    accounts = [:news_delivery, :webmaster_delivery]

    ApplicationMailer.descendants.each do |mailer|
      filters = mailer._process_action_callbacks.map(&:filter)
      assert(filters.intersect?(accounts),
             "#{mailer} sends with neither news_delivery nor " \
             "webmaster_delivery, so it falls back to the default account")
    end
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
