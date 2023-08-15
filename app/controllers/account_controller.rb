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

    return abort_signup_with_client_error if evil_signup_credentials?

    if make_sure_theme_is_valid!
      return render(action: :new) unless validate_and_save_new_user!

      UserGroup.create_user(@new_user)
      flash_notice("#{:runtime_signup_success.tp}#:{email_spam_notice.tp}")
      QueuedEmail::VerifyAccount.create_email(@new_user)
    end

    redirect_back_or_default(account_welcome_path)
  end

  # This is the welcome page for new users who just created an account.
  def welcome; end

  private #################################################

  def initialize_new_user
    now = Time.zone.now
    @new_user.attributes = {
      created_at: now,
      updated_at: now,
      last_login: now,
      admin: false,
      layout_count: 15,
      mailing_address: "",
      notes: "",
      login: strip_new_user_param(:login),
      name: strip_new_user_param(:name),
      theme: strip_new_user_param(:theme),
      email: strip_new_user_param(:email),
      email_confirmation: strip_new_user_param(:email_confirmation),
      password: strip_new_user_param(:password),
      password_confirmation: strip_new_user_param(:password_confirmation)
    }
  end

  def strip_new_user_param(arg)
    params[:new_user] && params[:new_user][arg].to_s.strip
  end

  # Block attempts to register by clients with known "evil" params,
  # where "evil" means: sending a Verification email will throw an error;
  # the Verification email will cause Undelivered Mail Returned to Send; and/or
  # it's a known spammer.
  def abort_signup_with_client_error
    # Too Many Requests == 429. Any 4xx status (Client Error) would also work.
    render(status: :too_many_requests,
           content_type: "text/plain",
           plain: "We blocked your signup because your chosen login name or " \
                  "email address matches one used by a spammer. " \
                  "Please contact us if you have been blocked in error.")
  end

  # Some recurring patterns we've noticed
  BOGUS_EMAILS = / namnerbca\.com |
                   0mg0mg0mg |
                   yourmail@gmail\.com |
                   @mnawl.sibicomail\.com
                   /ix

  # Some recurring patterns we've noticed
  BOGUS_LOGINS = / houghgype |
                   uplilla |
                   vemslons /ix

  def evil_signup_credentials?
    bogus_email? || bogus_login?
  end

  def bogus_email?
    BOGUS_EMAILS.match?(@new_user.email) ||
      # Spammer using variations of "b.l.izk.o.ya.n201.7@gmail.com\r\n"
      @new_user.email.remove(".").include?("blizkoyan") ||
      @new_user.email.count(".") > 5
  end

  def bogus_login?
    BOGUS_LOGINS.match?(@new_user.login)
  end

  def make_sure_theme_is_valid!
    theme = @new_user.theme
    login = @new_user.login
    valid_themes = MO.themes + ["NULL"]
    return true if valid_themes.member?(theme) && login != "test_denied"

    if theme.present?
      # I'm guessing this has something to do with spammer/hacker trying
      # to automate creation of accounts?

      QueuedEmail::Webmaster.create_email(
        sender_email: MO.accounts_email_address,
        subject: "Account Denied",
        content: denied_message(new_user)
      )
    end
    false
  end

  def denied_message(new_user)
    "The request for account #{new_user.login} was denied since the theme" \
    "was set to '#{new_user.theme}'.\n" \
    "Here are all the fields for the request user:\n\n" \
    "login: #{new_user.login}\n" \
    "password: #{new_user.password}\n" \
    "email: #{new_user.email}\n" \
    "theme: #{new_user.theme}\n" \
    "name: #{new_user.name}\n" \
  end

  def validate_and_save_new_user!
    make_sure_password_present!
    make_sure_email_confirmed!
    return true if @new_user.errors.none? && @new_user.save

    flash_object_errors(@new_user)
    false
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
end
