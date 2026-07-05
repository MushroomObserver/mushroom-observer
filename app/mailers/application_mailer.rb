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
    mail_args = mo_mail_args(title, to, headers, content_style)

    if (view_namespace = mailer_view_namespace)
      deliver_phlex_mail(mail_args, headers, content_style, view_namespace)
    else
      mail(**mail_args)
    end
    I18n.locale = @old_locale if I18n.locale != @old_locale
  end

  def mo_mail_args(title, to, headers, content_style)
    { subject: "[MO] #{title}", to: to,
      from: calc_email(headers[:from]) || MO.news_email_address,
      reply_to: calc_email(headers[:reply_to]) || MO.noreply_email_address,
      content_type: "text/#{content_style}" }
  end

  def deliver_phlex_mail(mail_args, headers, content_style, view_namespace)
    view = resolve_mailer_view(view_namespace,
                               headers.fetch(:view_params, {}), content_style)
    # ActionMailer's format-block methods are named after the Mime::Type
    # symbol ("text", "html"), not our "html"/"plain" content_style
    # vocabulary (used for the "text/#{content_style}" header above).
    mime_format = content_style == "plain" ? :text : :html
    mail(**mail_args) do |format|
      format.public_send(mime_format) { render(view) }
    end
  end

  # Phlex conversion (issue #4676): every converted mailer's Phlex
  # view lives at the mechanical `Views::Mailers::<MailerClassName>`
  # namespace (matching the `app/views/mailers/<same_name>/build.rb`
  # directory-naming convention every conversion follows) — no
  # per-mailer wiring needed. `safe_constantize` returns nil for a
  # not-yet-converted mailer, falling back to the old implicit ERB
  # template lookup in `mo_mail` above.
  def mailer_view_namespace
    "Views::Mailers::#{self.class.name}".safe_constantize
  end

  # `view_namespace` is a mailer's `Views::Mailers::<Name>` module.
  # Its `Html`/`Text` siblings (if defined) pick the one matching this
  # send's content_style; a mailer with no such split (its body
  # doesn't vary by format) just has a `Build` class, used for either
  # style. `Html`/`Text` are defined inline inside `build.rb` (not
  # their own files), so Zeitwerk only knows to autoload the `Build`
  # constant itself — referencing it first is what makes `Html`/
  # `Text` exist at all (as a side effect of loading that file);
  # `const_defined?` alone never triggers Zeitwerk's autoload.
  def resolve_mailer_view(view_namespace, view_params, content_style)
    view_namespace.const_get(:Build)
    variant = if view_namespace.const_defined?(:Html, false)
                if content_style == "html"
                  view_namespace.const_get(:Html)
                else
                  view_namespace.const_get(:Text)
                end
              else
                view_namespace.const_get(:Build)
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
