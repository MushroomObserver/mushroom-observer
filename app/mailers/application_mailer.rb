# frozen_string_literal: true

#  Base class for mailers for each type of email
class ApplicationMailer < ActionMailer::Base
  # Allow folder organization in the app/views folder
  append_view_path Rails.root.join("app/views/mailers")

  # Use native Ruby URI::MailTo class
  def self.valid_email_address?(address)
    address.to_s.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Prepend user info to content for context in emails to webmaster/admins.
  def self.prepend_user(user, content)
    return content if user.blank?

    "(from User ##{user.id} #{user.name}(#{user.login}))\n#{content}"
  end

  private

  def webmaster_delivery
    return if message.to.blank?

    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_webmaster
  end

  def news_delivery
    return if message.to.blank?

    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_news
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
    mail(subject: "[MO] #{title}",
         to: to,
         from: from,
         reply_to: reply_to,
         content_type: "text/#{content_style}")
    I18n.locale = @old_locale if I18n.locale != @old_locale
  end

  def debug_log(template, from, to, objects = {})
    msg =  "MAIL #{template}" # create mutable string
    msg << " from=#{from.id}" if from
    msg << " to=#{to.id}" if to
    objects.each do |k, v|
      value = v.nil? || v.instance_of?(String) ? v : v.id
      msg << " #{k}=#{value}"
    end
    Rails.root.join("log/email-debug.log").open("a:utf-8") do |fh|
      fh.puts("#{Time.zone.now} #{msg}")
    end
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
