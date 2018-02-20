#  Base class for mailers for each type of email
class AccountMailer < ActionMailer::Base
  private

  def setup_user(user)
    @user = user
    I18n.locale = @user.try(&:locale) || MO.default_locale
  end

  def mo_mail(title, headers = {})
    to = calc_email(headers[:to])
    content_style = calc_content_style(headers)
    from = calc_email(headers[:from]) || MO.news_email_address
    reply_to = calc_email(headers[:reply_to]) || MO.noreply_email_address
    mail(subject: "[MO] #{title.to_ascii}",
         to: to,
         from: from,
         reply_to: reply_to,
         content_type: "text/#{content_style}")
  end

  def debug_log(template, from, to, objects = {})
    msg = "MAIL #{template}"
    msg << " from=#{from.id}" if from
    msg << " to=#{to.id}" if to
    objects.each do |k, v|
      value = (v.nil? || v.class == String) ? v : v.id
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
end
