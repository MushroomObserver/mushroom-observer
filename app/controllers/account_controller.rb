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
    :email_new_password,
    :login,
    :logout_user,
    :reverify,
    :send_verify,
    :signup,
    :verify,
    :welcome
  ]
  before_action :disable_link_prefetching, except: [
    :login,
    :signup,
    :prefs,
    :profile
  ]

  ##############################################################################
  #
  #  :section: Sign-up
  #
  ##############################################################################

  def signup
    @new_user = User.new(theme: MO.default_theme)
    return if request.method != "POST"

    initialize_new_user
    return if block_evil_signups!
    return unless make_sure_theme_is_valid!
    return unless validate_and_save_new_user!

    UserGroup.create_user(@new_user)
    flash_notice(:runtime_signup_success.tp + :email_spam_notice.tp)
    VerifyEmail.build(@new_user).deliver_now
    notify_root_of_blocked_verification_email(@new_user)
    redirect_back_or_default(action: :welcome)
  end

  def verify
    id        = params["id"]
    auth_code = params["auth_code"]
    return unless (user = find_or_goto_index(User, id))

    # This will happen legitimately whenever a non-verified user tries to
    # login.  The user just gets redirected here instead of being properly
    # logged in.  "auth_code" will be missing.
    if auth_code != user.auth_code
      @unverified_user = user
      render(action: :reverify)

    # If already logged in and verified, just send to "welcome" page.
    elsif @user == user
      redirect_to(action: :welcome)

    # If user is already verified, send them back to the login page.  (If
    # someone grabs a user's verify email, they could theoretically use it to
    # log in any time they wanted to.  This makes it a one-time use.)
    elsif user.verified
      flash_warning(:runtime_reverify_already_verified.t)
      @user = nil
      User.current = nil
      session_user_set(nil)
      redirect_to(action: :login)

    # If user was created via API, we must ask the user to choose a password
    # first before we can verify them.
    elsif user.password.blank?
      @user = user
      if request.method == "POST"
        password = begin
                     params[:user][:password]
                   rescue StandardError
                     nil
                   end
        confirmation = begin
                         params[:user][:password_confirmation]
                       rescue StandardError
                         nil
                       end
        if password.blank?
          @user.errors.add(:password, :validate_user_password_missing.t)
        elsif password != confirmation
          @user.errors.add(:password_confirmation,
                           :validate_user_password_no_match.t)
        elsif password.length < 5 || password.size > 40
          @user.errors.add(:password, :validate_user_password_too_long.t)
        else
          User.current = @user
          session_user_set(@user)
          @user.change_password(password)
          @user.verify
        end
        if user.errors.any?
          @user.password = password
          flash_object_errors(user)
          render(action: :choose_password)
        end
      else
        flash_warning(:account_choose_password_warning.t)
        render(action: :choose_password)
      end

    # If not already verified, and the code checks out, then mark account
    # "verified", log user in, and display the "you're verified" page.
    else
      @user = user
      User.current = user
      session_user_set(user)
      @user.verify
    end
  end

  # This action is never actually used.  Its template is rendered by verify.
  def reverify
    raise("This action should never occur!")
  end

  # This is used by the "reverify" page to re-send the verification email.
  def send_verify
    return unless (user = find_or_goto_index(User, params[:id].to_s))

    VerifyEmail.build(user).deliver_now
    notify_root_of_verification_email(user)
    flash_notice(:runtime_reverify_sent.tp + :email_spam_notice.tp)
    redirect_back_or_default(action: :welcome)
  end

  # This is the welcome page for new users who just created an account.
  def welcome; end

  ##############################################################################
  #
  #  :section: Login
  #
  ##############################################################################

  def login
    request.method == "POST" ? login_post : login_get
  end

  def email_new_password
    request.method == "POST" ? email_new_password_post : email_new_password_get
  end

  def logout_user
    # Safeguard: reset admin's session to their real_user_id
    if session[:real_user_id].present? &&
       (new_user = User.safe_find(session[:real_user_id])) &&
       new_user.admin
      switch_to_user(new_user)
      redirect_back_or_default("/")
    else
      @user = nil
      User.current = nil
      session_user_set(nil)
      session[:admin] = false
      clear_autologin_cookie
    end
  end

  # ========= private Login section methods ==========

  private

  def switch_to_user(new_user)
    if session[:real_user_id].blank?
      session[:real_user_id] = User.current_id
      session[:admin] = nil
    elsif session[:real_user_id] == new_user.id
      session[:real_user_id] = nil
      session[:admin] = true
    end
    User.current = new_user
    session_user_set(new_user)
  end

  def login_get
    @login = ""
    @remember = true
  end

  def login_post
    user_params = params[:user] || {}
    @login = user_params[:login].to_s
    @password = user_params[:password].to_s
    @remember = user_params[:remember_me] == "1"
    user = User.authenticate(login: @login, password: @password)
    user ||= User.authenticate(login: @login, password: @password.strip)

    return flash_error(:runtime_login_failed.t) unless user

    user.verified ? login_success(user) : login_unverified(user)
  end

  def login_success(user)
    flash_notice(:runtime_login_success.t)
    @user = user
    @user.last_login = now = Time.zone.now
    @user.updated_at = now
    @user.save
    User.current = @user
    session_user_set(@user)
    @remember ? autologin_cookie_set(@user) : clear_autologin_cookie
    redirect_back_or_default(action: :welcome)
  end

  def login_unverified(user)
    @unverified_user = user
    render(action: "reverify")
  end

  def email_new_password_get
    @new_user = User.new
  end

  def email_new_password_post
    @login = params["new_user"]["login"]
    @new_user = User.where("login = ? OR name = ? OR email = ?",
                           @login, @login, @login).first
    if @new_user.nil?
      flash_error(:runtime_email_new_password_failed.t(user: @login))
    else
      password = String.random(10)
      @new_user.change_password(password)
      if @new_user.save
        flash_notice(:runtime_email_new_password_success.tp +
                     :email_spam_notice.tp)
        PasswordEmail.build(@new_user, password).deliver_now
        render(action: "login")
      else
        flash_object_errors(@new_user)
      end
    end
  end

  public

  ##############################################################################
  #
  #  :section: Preferences and Profile
  #
  ##############################################################################

  def remove_image
    if @user&.image
      @user.update(image: nil)
      flash_notice(:runtime_profile_removed_image.t)
    end
    redirect_to(user_path(@user.id))
  end

  def no_email_comments_owner
    no_email("comments_owner")
  end

  def no_email_comments_response
    no_email("comments_response")
  end

  def no_email_comments_all
    no_email("comments_all")
  end

  def no_email_observations_consensus
    no_email("observations_consensus")
  end

  def no_email_observations_naming
    no_email("observations_naming")
  end

  def no_email_observations_all
    no_email("observations_all")
  end

  def no_email_names_admin
    no_email("names_admin")
  end

  def no_email_names_author
    no_email("names_author")
  end

  def no_email_names_editor
    no_email("names_editor")
  end

  def no_email_names_reviewer
    no_email("names_reviewer")
  end

  def no_email_names_all
    no_email("names_all")
  end

  def no_email_locations_admin
    no_email("locations_admin")
  end

  def no_email_locations_author
    no_email("locations_author")
  end

  def no_email_locations_editor
    no_email("locations_editor")
  end

  def no_email_locations_all
    no_email("locations_all")
  end

  def no_email_general_feature
    no_email("general_feature")
  end

  def no_email_general_commercial
    no_email("general_commercial")
  end

  def no_email_general_question
    no_email("general_question")
  end

  # These are the old email flags, renamed in favor of more consistent ones.
  alias no_comment_email no_email_comments_owner
  alias no_comment_response_email no_email_comments_response
  alias no_commercial_email no_email_general_commercial
  alias no_consensus_change_email no_email_observations_consensus
  alias no_feature_email no_email_general_feature
  alias no_name_change_email no_email_names_author
  alias no_name_proposal_email no_email_observations_naming
  alias no_question_email no_email_general_question

  def no_email(type)
    user = User.safe_find(params[:id])
    if user && check_permission!(user)
      method  = "email_#{type}="
      prefix  = "no_email_#{type}"
      success = "#{prefix}_success".to_sym
      @note   = "#{prefix}_note".to_sym
      @user.send(method, false)
      if @user.save
        flash_notice(success.t(name: @user.unique_text_name))
        render(action: :no_email)
      else
        # Probably should write a better error message here...
        flash_object_errors(@user)
        redirect_to("/")
      end
    else
      redirect_to("/")
    end
  end

  def api_keys
    @key = APIKey.new
    return unless request.method == "POST"

    if params[:commit] == :account_api_keys_create_button.l
      create_api_key
    else
      remove_api_keys
    end
  end

  def create_api_key
    @key = APIKey.new(params[:key].permit!)
    @key.verified = Time.zone.now
    @key.save!
    @key = APIKey.new # blank out form for if they want to create another key
    flash_notice(:account_api_keys_create_success.t)
  rescue StandardError => e
    flash_error(:account_api_keys_create_failed.t(msg: e.to_s))
  end

  def remove_api_keys
    num_destroyed = 0
    @user.api_keys.each do |key|
      if params["key_#{key.id}"] == "1"
        @user.api_keys.delete(key)
        num_destroyed += 1
      end
    end
    if num_destroyed.positive?
      flash_notice(:account_api_keys_removed_some.t(num: num_destroyed))
    else
      flash_warning(:account_api_keys_removed_none.t)
    end
  end

  def activate_api_key
    if (key = find_or_goto_index(APIKey, params[:id].to_s))
      if check_permission!(key)
        key.verify!
        flash_notice(:account_api_keys_activated.t(notes: key.notes))
      end
      redirect_to(action: :api_keys)
    end
  rescue StandardError => e
    flash_error(e.to_s)
  end

  def edit_api_key
    return unless (@key = find_or_goto_index(APIKey, params[:id].to_s))
    return redirect_to(action: :api_keys) unless check_permission!(@key)
    return if request.method != "POST"

    update_api_key if params[:commit] == :UPDATE.l
    redirect_to(action: :api_keys)
  rescue StandardError => e
    flash_error(e.to_s)
  end

  def update_api_key
    @key.update!(params[:key].permit(:notes))
    flash_notice(:account_api_keys_updated.t)
  end

  ##############################################################################
  #
  #  :section: Testing
  #
  ##############################################################################

  # This is used to test the autologin feature.
  def test_autologin; end

  ##############################################################################

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
    }.merge(params.require(:new_user).permit(:login, :name, :theme,
                                             :email, :email_confirmation,
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
    url = "#{MO.http_domain}/account/verify/#{user.id}?" \
          "auth_code=#{user.auth_code}"
    subject = :email_subject_verify.l
    content = :email_verify_intro.tp(user: user.login, link: url)
    content = "email: #{user.email}\n\n" + content.html_to_ascii
    WebmasterEmail.build(user.email, content, subject).deliver_now
  end
end
