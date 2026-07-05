# frozen_string_literal: true

#  Base class for mailers for each type of email
class ApplicationMailer < ActionMailer::Base
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
    mail_args = mo_mail_args(title, to, headers, content_style)
    deliver_phlex_mail(mail_args, headers, content_style, mailer_view_class)
    I18n.locale = @old_locale if I18n.locale != @old_locale
  end

  def mo_mail_args(title, to, headers, content_style)
    { subject: "[MO] #{title}", to: to,
      from: calc_email(headers[:from]) || MO.news_email_address,
      reply_to: calc_email(headers[:reply_to]) || MO.noreply_email_address,
      content_type: "text/#{content_style}" }
  end

  def deliver_phlex_mail(mail_args, headers, content_style, view_class)
    view = resolve_mailer_view(view_class,
                               headers.fetch(:view_params, {}), content_style)
    # ActionMailer's format-block methods are named after the Mime::Type
    # symbol ("text", "html"), not our "html"/"plain" content_style
    # vocabulary (used for the "text/#{content_style}" header above).
    mime_format = content_style == "plain" ? :text : :html
    mail(**mail_args) do |format|
      format.public_send(mime_format) { render(view) }
    end
  end

  # Every mailer's Phlex view lives at the mechanical
  # `Views::Mailers::<MailerClassName>` class (matching the
  # `app/views/mailers/<same_name>.rb` file-naming convention every
  # mailer follows) — no per-mailer wiring needed.
  def mailer_view_class
    "Views::Mailers::#{self.class.name}".constantize
  end

  # `view_class`'s `Html`/`Text` nested classes (if defined) pick the
  # one matching this send's content_style; a mailer with no such
  # split (its body doesn't vary by format) uses `view_class` itself
  # for either style.
  def resolve_mailer_view(view_class, view_params, content_style)
    variant = if view_class.const_defined?(:Html, false)
                if content_style == "html"
                  view_class.const_get(:Html)
                else
                  view_class.const_get(:Text)
                end
              else
                view_class
              end
    variant.new(**view_params)
  end

  def debug_log(template, from, to, objects = {})
    msg =  "MAIL #{template}" # create mutable string
    msg << " from=#{from.id}" if from
    msg << " to=#{to.id}" if to
    objects.each do |k, v|
      value = v.nil? || v.instance_of?(String) ? v : v.id
      msg << " #{k}=#{value}"
    end
    MO.email_debug_log_path.open("a:utf-8") do |fh|
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
