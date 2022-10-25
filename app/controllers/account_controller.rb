# frozen_string_literal: true

#
#  Account Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  ==== Sign-up
#  signup::             <tt>(. V P)</tt> Create new account.
#  verify::             <tt>(. V .)</tt> Verify new account.
#  reverify::           <tt>(. V .)</tt> If verify fails(?)
#  send_verify::        <tt>(. . .)</tt> Callback used by reverify.
#  welcome::            <tt>(. V .)</tt> Welcome page after signup and verify.
#
#  ==== Login
#  login::              <tt>(. V P)</tt>
#  logout_user::        <tt>(. V .)</tt>
#  email_new_password:: <tt>(. V .)</tt>
#
#  ==== Preferences
#  prefs::              <tt>(L V P)</tt>
#  profile::            <tt>(L V P)</tt>
#  remove_image::       <tt>(L . .)</tt>
#  no_email::           <tt>(L V .)</tt>
#  api_keys::           <tt>(L V .)</tt>
#
#  ==== Testing
#  test_autologin::     <tt>(L V .)</tt>
#
################################################################################
class AccountController < ApplicationController
  before_action :login_required, except: [
    :new,
    :create,
    :welcome
  ]
  before_action :disable_link_prefetching, except: [
    :new
  ]

  ##############################################################################
  #
  #  :section: Sign-up
  #
  ##############################################################################

  def new
    @new_user = User.new(theme: MO.default_theme)
  end

  def create
    @new_user = User.new(theme: MO.default_theme)

    initialize_new_user
    # return if block_evil_signups!
    # return unless make_sure_theme_is_valid!
    # return unless validate_and_save_new_user!

    return if block_evil_signups!
    return unless make_sure_theme_is_valid! && validate_and_save_new_user!

    UserGroup.create_user(@new_user)
    flash_notice(:runtime_signup_success.tp + :email_spam_notice.tp)
    VerifyEmail.build(@new_user).deliver_now
    notify_root_of_blocked_verification_email(@new_user)
    redirect_back_or_default(account_welcome_path)
  end

  # This is the welcome page for new users who just created an account.
  def welcome; end

  private

  def initialize_new_user
    now = Time.zone.now
    @new_user.attributes = {
      created_at: now,
      updated_at: now,
      last_login: now,
      admin: false,
      layout_count: 15,
      mailing_address: "",
      notes: ""
    }.merge(params.require(:new_user).
                   permit(:login, :name, :theme, :email, :email_confirmation,
                          :password, :password_confirmation))
  end

  # Block attempts to register by clients with known "evil" params,
  # where "evil" means: sending a Verification email will throw an error;
  # the Verification email will cause Undelivered Mail Returned to Send; and/or
  # it's a known spammer.
  def block_evil_signups!
    return false unless evil_signup_credentials?

    # Too Many Requests == 429. Any 4xx status (Client Error) would also work.
    render(status: :too_many_requests,
           content_type: "text/plain",
           plain: "We grow weary of this. Please go away.")
    true
  end

  def evil_signup_credentials?
    /(Vemslons|Uplilla)$/ =~ @new_user.login ||
      /namnerbca.com$/ =~ @new_user.email ||
      # Spammer using variations of "b.l.izk.o.ya.n201.7@gmail.com\r\n"
      @new_user.email.remove(".").include?("blizkoyan2017")
  end

  def make_sure_theme_is_valid!
    theme = @new_user.theme
    login = @new_user.login
    valid_themes = MO.themes + ["NULL"]
    return true if valid_themes.member?(theme) && login != "test_denied"

    if theme.present?
      # I'm guessing this has something to do with spammer/hacker trying
      # to automate creation of accounts?
      DeniedEmail.build(params["new_user"]).deliver_now
    end
    redirect_back_or_default(action: :welcome)
    false
  end

  def validate_and_save_new_user!
    make_sure_password_present!
    make_sure_email_confirmed!
    return true if @new_user.errors.none? && @new_user.save

    flash_object_errors(@new_user)
    render(:new) and return false
  end

  # I think this is not in the User model validations because of tests or
  # something.  I can't fathom why any "real" user would ever be allowed not
  # to have a password!
  def make_sure_password_present!
    return if @new_user.password.present?

    @new_user.errors.add(:password, :validate_user_password_missing.t)
  end

  # Same with this.  When I moved this to User validates, all hell broke
  # loose in unit tests.  This is some of the earliest code on the site,
  # not surprising we didn't get it right!
  def make_sure_email_confirmed!
    if @new_user.email.blank?
      # Already complained about this in User validates.
    elsif @new_user.email_confirmation.blank?
      @new_user.errors.add(:email, :validate_user_email_confirmation_missing.t)
    elsif @new_user.email != @new_user.email_confirmation
      @new_user.errors.add(:email, :validate_user_email_mismatch.t)
    end
  end

  SPAM_BLOCKERS = %w[
    hotmail.com
    live.com
  ].freeze

  BOGUS_LOGINS = /houghgype|vemslons/

  def notify_root_of_blocked_verification_email(user)
    domain = user.email.to_s.sub(/^.*@/, "")
    return unless SPAM_BLOCKERS.any?(domain)
    return if user.login.to_s.match(BOGUS_LOGINS)

    notify_root_of_verification_email(user)
  end

  def notify_root_of_verification_email(user)
    url = "#{MO.http_domain}/account/verify/new/#{user.id}?" \
          "auth_code=#{user.auth_code}"
    subject = :email_subject_verify.l
    content = :email_verify_intro.tp(user: user.login, link: url)
    content = "email: #{user.email}\n\n" + content.html_to_ascii
    WebmasterEmail.build(user.email, content, subject).deliver_now
  end
end
