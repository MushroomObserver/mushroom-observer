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
#  ==== Admin utilities
#  turn_admin_on::      <tt>(R . .)</tt>
#  turn_admin_off::     <tt>(R . .)</tt>
#  switch_users::       <tt>(R V .)</tt>
#  add_user_to_group::  <tt>(R V .)</tt>
#  create_alert::       <tt>(R V .)</tt>
#  destroy_user::       <tt>(R . .)</tt>
#  blocked_ips::        <tt>(R V .)</tt>
#
#  ==== Testing
#  test_autologin::     <tt>(L V .)</tt>
#  test_flash::         <tt>(. . .)</tt>
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
    :test_flash,
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
      if request.method != "POST"
        flash_warning(:account_choose_password_warning.t)
        render(action: :choose_password)
      else
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
    if session[:real_user_id].present? &&
       (new_user = User.safe_find(session[:real_user_id])) &&
       new_user.admin
      switch_to_user(new_user)
      redirect_back_or_default(controller: :observer, action: :index)
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

  # Table for converting form value to object value
  # Used by update_prefs_from_form
  def prefs_types # rubocop:disable Metrics/MethodLength
    [
      [:email_comments_all, :boolean],
      [:email_comments_owner, :boolean],
      [:email_comments_response, :boolean],
      [:email_general_commercial, :boolean],
      [:email_general_feature, :boolean],
      [:email_general_question, :boolean],
      [:email_html, :boolean],
      [:email_locations_admin, :boolean],
      [:email_locations_all, :boolean],
      [:email_locations_author, :boolean],
      [:email_locations_editor, :boolean],
      [:email_names_admin, :boolean],
      [:email_names_all, :boolean],
      [:email_names_author, :boolean],
      [:email_names_editor, :boolean],
      [:email_names_reviewer, :boolean],
      [:email_observations_all, :boolean],
      [:email_observations_consensus, :boolean],
      [:email_observations_naming, :boolean],
      [:email, :string],
      [:hide_authors, :enum],
      [:image_size, :enum],
      [:keep_filenames, :enum],
      [:layout_count, :integer],
      [:license_id, :integer],
      [:locale, :string],
      [:location_format, :enum],
      [:login, :string],
      [:notes_template, :string],
      [:theme, :string],
      [:thumbnail_maps, :boolean],
      [:thumbnail_size, :enum],
      [:view_owner_id, :boolean],
      [:votes_anonymous, :enum]
    ] + content_filter_types
  end

  def content_filter_types
    ContentFilter.all.map do |fltr|
      [fltr.sym, :content_filter]
    end
  end

  def prefs
    @licenses = License.current_names_and_ids(@user.license)
    return unless request.method == "POST"

    update_password
    update_prefs_from_form
    return unless prefs_changed_successfully

    update_copyright_holder(@user.legal_name_change)
  end

  def update_password
    return unless (password = params["user"]["password"])

    if password == params["user"]["password_confirmation"]
      @user.change_password(password)
    else
      @user.errors.add(:password, :runtime_prefs_password_no_match.t)
    end
  end

  def update_prefs_from_form
    prefs_types.each do |pref, type|
      val = params[:user][pref]
      case type
      when :string  then update_pref(pref, val.to_s)
      when :integer then update_pref(pref, val.to_i)
      when :boolean then update_pref(pref, val == "1")
      when :enum    then update_pref(pref, val || User.enum_default_value(pref))
      when :content_filter then update_content_filter(pref, val)
      end
    end
  end

  def update_pref(pref, val)
    @user.send("#{pref}=", val) if @user.send(pref) != val
  end

  def update_content_filter(pref, val)
    filter = ContentFilter.find(pref)
    @user.content_filter[pref] =
      if filter.type == :boolean && filter.prefs_vals.count == 1
        val == "1" ? filter.prefs_vals.first : filter.off_val
      else
        val.to_s
      end
  end

  def update_copyright_holder(legal_name_change = nil)
    return unless legal_name_change

    Image.update_copyright_holder(*legal_name_change, @user)
  end

  def prefs_changed_successfully
    result = false
    if !@user.changed
      flash_notice(:runtime_no_changes.t)
    elsif !@user.errors.empty? || !@user.save
      flash_object_errors(@user)
    else
      flash_notice(:runtime_prefs_success.t)
      result = true
    end
    result
  end

  def profile
    @licenses = License.current_names_and_ids(@user.license)
    if request.method != "POST"
      @place_name        = @user.location ? @user.location.display_name : ""
      @copyright_holder  = @user.legal_name
      @copyright_year    = Time.zone.now.year
      @upload_license_id = @user.license.id

    else
      [:name, :notes, :mailing_address].each do |arg|
        val = params[:user][arg].to_s
        @user.send("#{arg}=", val) if @user.send(arg) != val
      end

      # Make sure the given location exists before accepting it.
      @place_name = params["user"]["place_name"].to_s
      if @place_name.present?
        location = Location.find_by_name_or_reverse_name(@place_name)
        if !location
          need_to_create_location = true
        elsif @user.location != location
          @user.location = location
          @place_name = location.display_name
        end
      elsif @user.location
        @user.location = nil
      end

      # Check if we need to upload an image.
      upload = params["user"]["upload_image"]
      if upload.present?
        date = Date.parse("#{params["date"]["copyright_year"]}0101")
        license = License.safe_find(params["upload"]["license_id"])
        holder = params["copyright_holder"]
        image = Image.new(
          image: upload,
          user: @user,
          when: date,
          copyright_holder: holder,
          license: license
        )
        if !image.save
          flash_object_errors(image)
        elsif !image.process_image
          name = image.original_name
          name = "???" if name.empty?
          flash_error(:runtime_profile_invalid_image.t(name: name))
          flash_object_errors(image)
        else
          @user.image = image
          name = image.original_name
          name = "##{image.id}" if name.empty?
          flash_notice(:runtime_profile_uploaded_image.t(name: name))
        end
      end

      # compute legal name change now because @user.save will overwrite it
      legal_name_change = @user.legal_name_change
      if !@user.changed
        flash_notice(:runtime_no_changes.t)
        redirect_to(controller: "observer", action: "show_user", id: @user.id)
      elsif !@user.save
        flash_object_errors(@user)
      else
        update_copyright_holder(legal_name_change)
        if need_to_create_location
          flash_notice(:runtime_profile_must_define.t)
          redirect_to(controller: "location", action: "create_location",
                      where: @place_name, set_user: @user.id)
        else
          flash_notice(:runtime_profile_success.t)
          redirect_to(controller: "observer", action: "show_user", id: @user.id)
        end
      end
    end
  end

  def remove_image
    if @user&.image
      @user.update(image: nil)
      flash_notice(:runtime_profile_removed_image.t)
    end
    redirect_to(controller: "observer", action: "show_user", id: @user.id)
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
        redirect_to(controller: :observer, action: :list_rss_logs)
      end
    else
      redirect_to(controller: :observer, action: :list_rss_logs)
    end
  end

  def api_keys
    @key = ApiKey.new
    return unless request.method == "POST"

    if params[:commit] == :account_api_keys_create_button.l
      create_api_key
    else
      remove_api_keys
    end
  end

  def create_api_key
    @key = ApiKey.new(params[:key].permit!)
    @key.verified = Time.zone.now
    @key.save!
    @key = ApiKey.new # blank out form for if they want to create another key
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
    if (key = find_or_goto_index(ApiKey, params[:id].to_s))
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
    return unless @key = find_or_goto_index(ApiKey, params[:id].to_s)
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
  #  :section: Admin utilities
  #
  ##############################################################################

  def turn_admin_on
    session[:admin] = true if @user&.admin && !in_admin_mode?
    redirect_back_or_default(controller: :observer, action: :index)
  end

  def turn_admin_off
    session[:admin] = nil
    redirect_back_or_default(controller: :observer, action: :index)
  end

  def switch_users
    @id = params[:id].to_s
    new_user = find_user_by_id_login_or_email(@id)
    flash_error("Couldn't find \"#{@id}\".  Play again?") \
      if new_user.blank? && @id.present?
    if !@user&.admin && session[:real_user_id].blank?
      redirect_back_or_default(controller: :observer, action: :index)
    elsif new_user.present?
      switch_to_user(new_user)
      redirect_back_or_default(controller: :observer, action: :index)
    end
  end

  def find_user_by_id_login_or_email(str)
    if str.blank?
      nil
    elsif str.match?(/^\d+$/)
      User.safe_find(str)
    else
      User.find_by_login(str) || User.find_by_email(str.sub(/ <.*>$/, ""))
    end
  end

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

  def add_user_to_group
    in_admin_mode? ? add_user_to_group_admin_mode : add_user_to_group_user_mode
  end

  # This is messy, but the new User#erase_user method makes a pretty good
  # stab at the problem.
  def destroy_user
    if in_admin_mode?
      id = params["id"]
      if id.present?
        user = User.safe_find(id)
        User.erase_user(id) if user
      end
    end
    redirect_back_or_default("/")
  end

  def blocked_ips
    if in_admin_mode?
      process_blocked_ips_commands
      @blocked_ips = sort_by_ip(IpStats.read_blocked_ips)
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(:do_activity)
    else
      redirect_back_or_default("/observer/how_to_help")
    end
  end

  # ========= private Admin utilities section methods ==========

  private

  def sort_by_ip(ips)
    ips.sort_by do |ip|
      ip.to_s.split(".").map { |n| n.to_i + 1000 }.map(&:to_s).join(" ")
    end
  end

  # rubocop:disable Metrics/AbcSize
  # I think this is as good as it gets: just a simple switch statement of
  # one-line commands.  Breaking this up doesn't make sense to me.
  # -JPH 2020-10-09
  def process_blocked_ips_commands
    if validate_ip!(params[:add_okay])
      IpStats.add_okay_ips([params[:add_okay]])
    elsif validate_ip!(params[:add_bad])
      IpStats.add_blocked_ips([params[:add_bad]])
    elsif validate_ip!(params[:remove_okay])
      IpStats.remove_okay_ips([params[:remove_okay]])
    elsif validate_ip!(params[:remove_bad])
      IpStats.remove_blocked_ips([params[:remove_bad]])
    elsif params[:clear_okay].present?
      IpStats.clear_okay_ips
    elsif params[:clear_bad].present?
      IpStats.clear_blocked_ips
    elsif validate_ip!(params[:report])
      @ip = params[:report]
    end
  end
  # rubocop:enable Metrics/AbcSize

  def validate_ip!(ip)
    return false if ip.blank?

    match = ip.to_s.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
    return true if match &&
                   valid_ip_num(match[1]) &&
                   valid_ip_num(match[2]) &&
                   valid_ip_num(match[3]) &&
                   valid_ip_num(match[4])

    flash_error("Invalid IP address: \"#{ip}\"")
  end

  def valid_ip_num(num)
    num.to_i >= 0 && num.to_i < 256
  end

  def add_user_to_group_admin_mode
    return unless request.method == "POST"

    user_name  = params["user_name"].to_s
    group_name = params["group_name"].to_s
    user       = User.find_by(login: user_name)
    group      = UserGroup.find_by(name: group_name)

    if can_add_user_to_group?(user, group)
      do_add_user_to_group(user, group)
    else
      do_not_add_user_to_group(user, group, user_name, group_name)
    end

    redirect_back_or_default(controller: "observer", action: "index")
  end

  def can_add_user_to_group?(user, group)
    user && group && !user.user_groups.member?(group)
  end

  def do_add_user_to_group(user, group)
    user.user_groups << group
    flash_notice(:add_user_to_group_success. \
      t(user: user.name, group: group.name))
  end

  def do_not_add_user_to_group(user, group, user_name, group_name)
    if user && group
      flash_warning(:add_user_to_group_already. \
        t(user: user_name, group: group_name))
    else
      flash_error(:add_user_to_group_no_user.t(user: user_name)) unless user
      flash_error(:add_user_to_group_no_group.t(group: group_name)) unless group
    end
  end

  def add_user_to_group_user_mode
    flash_error(:permission_denied.t)
    redirect_back_or_default(controller: "observer", action: "index")
  end

  public

  ##############################################################################
  #
  #  :section: Testing
  #
  ##############################################################################

  # This is used to test the autologin feature.
  def test_autologin; end

  # This is used to test the flash error mechanism in the unit tests.
  def test_flash
    notice   = params[:notice]
    warning  = params[:warning]
    error    = params[:error]
    redirect = params[:redirect]
    flash_notice(notice)   if notice
    flash_warning(warning) if warning
    flash_error(error)     if error
    if redirect
      redirect_to(redirect)
    else
      render(plain: "", layout: true)
    end
  end

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
      /(\.xyz|namnerbca.com)$/ =~ @new_user.email ||
      # Spammer using variations of "b.l.izk.o.ya.n201.7@gmail.com\r\n"
      /blizkoyan2017/ =~ @new_user.email.remove(".")
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

  BOGUS_LOGINS = /houghgype|vemslons/.freeze

  def notify_root_of_blocked_verification_email(user)
    domain = user.email.to_s.sub(/^.*@/, "")
    return unless SPAM_BLOCKERS.any? { |d| domain == d }
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
