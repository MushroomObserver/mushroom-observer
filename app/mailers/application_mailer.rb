# frozen_string_literal: true

# I would rather do error handling in mo_mail() instead of having to catch a
# bunch of errors everywhere we call deliver_now.  The problem is build returns
# an instance of Mail::Message, and there doesn't seem to be any easy or safe
# way to validate email addresses or anything at that point.  If the user were
# initiating the mail message, that would be a different matter maybe, because
# then we could actually do something with the error messages.  But mostly the
# webmaster gets these error messages asynchronously from the rake email:send
# task, and at that point there's nothing anyone can do, so the error messages
# are just annoying and useless.  In the few cases where emails are sent
# immediately and not queued, I recommend explicitly checking for correctable
# errors *before* building and attempting to deliver the message. -JPH 20221108
ActionMailer::Base.raise_delivery_errors = false

#  Base class for mailers for each type of email
class ApplicationMailer < ActionMailer::Base
  # Use native Ruby URI::MailTo class
  def self.valid_email_address?(address)
    address.to_s.match?(URI::MailTo::EMAIL_REGEXP)
  end

  private

  def webmaster_delivery
    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_webmaster
  end

  def news_delivery
    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_news
  end

  def noreply_delivery
    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_noreply
  end

  def setup_user(user)
    @user = user
    @old_locale = I18n.locale
    new_locale = @user.try(&:locale) || MO.default_locale
    # Setting I18n.locale used to incur a significant performance penalty,
    # avoid doing so if not required.  Not sure if this is still the case.
    I18n.locale = new_locale if I18n.locale != new_locale
  end

  def mo_mail(title, headers = {})
    return unless (to = to_address(headers[:to]))

    content_style = calc_content_style(headers)
    from = calc_email(headers[:from]) || MO.news_email_address
    reply_to = calc_email(headers[:reply_to]) || MO.noreply_email_address
    mail(subject: "[MO] #{title.to_ascii}",
         to: to,
         from: from,
         reply_to: reply_to,
         content_type: "text/#{content_style}")
    I18n.locale = @old_locale if I18n.locale != @old_locale
  end

  def debug_log(template, from, to, objects = {})
    msg = + "MAIL #{template}" # create mutable string
    msg << " from=#{from.id}" if from
    msg << " to=#{to.id}" if to
    objects.each do |k, v|
      value = v.nil? || v.instance_of?(String) ? v : v.id
      msg << " #{k}=#{value}"
    end
    QueuedEmail.debug_log(msg)
  end

  def calc_content_style(headers)
    headers[:content_style] || content_style_from_to(headers[:to])
  end

  def content_style_from_to(user)
    user.respond_to?(:email_html) && !user.email_html ? "plain" : "html"
  end

  def calc_email(user)
    user.respond_to?(:email) ? user.email : user
  end

  def to_address(user)
    # I just want to be extra certain that we don't accidentally send email
    # to anyone who has opted out of all email.
    return nil if user.is_a?(::User) && user.no_emails

    address = calc_email(user)
    return nil unless ApplicationMailer.valid_email_address?(address)

    address
  end
end
