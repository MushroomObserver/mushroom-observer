# encoding: utf-8
#
#  = Account Controller
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
#  show_alert::         <tt>(. V .)</tt>
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
#  add_user_to_group::  <tt>(R V .)</tt>
#  create_alert::       <tt>(R V .)</tt>
#  destroy_user::       <tt>(R . .)</tt>
#
#  ==== Testing
#  test_autologin::     <tt>(L V .)</tt>
#  test_flash::         <tt>(. . .)</tt>
#
#  :all_norobots:
#
################################################################################
class AccountController < ApplicationController
  before_action :login_required, except: [
    :email_new_password,
    :login,
    :logout_user,
    :reverify,
    :send_verify,
    :show_alert,
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

  def signup # :nologin: :prefetch:
    if request.method != "POST"
      @new_user = User.new(theme: MO.default_theme)
    else
      theme = params["new_user"]["theme"]
      login = params["new_user"]["login"]
      valid_themes = MO.themes + ["NULL"]
      if !valid_themes.member?(theme) || (login == "test_denied")
        unless theme.blank?
          # I'm guessing this has something to do with spammer/hacker trying
          # to automate creation of accounts?
          DeniedEmail.build(params["new_user"]).deliver_now
        end
        redirect_back_or_default(action: :welcome)
      else
        permitted = params.require(:new_user).
                    permit(:email, :login, :name, :password,
                           :password_confirmation, :theme)
        @new_user = User.new(permitted)
        @new_user.created_at = now = Time.now
        @new_user.updated_at = now
        @new_user.last_login = now
        @new_user.admin = false
        @new_user.created_here = true
        @new_user.layout_count = 15
        @new_user.mailing_address = ""
        @new_user.notes = ""
        if @new_user.password.blank?
          @new_user.errors.add(:password, :validate_user_password_missing.t)
        end
        if @new_user.errors.any? ||
           !@new_user.save
          flash_object_errors(@new_user)
        else
          group = UserGroup.create_user(@new_user)
          flash_notice (:runtime_signup_success.tp + :email_spam_notice.tp)
          VerifyEmail.build(@new_user).deliver_now
          redirect_back_or_default(action: :welcome)
        end
      end
    end
  end

  def verify # :nologin:
    id        = params["id"]
    auth_code = params["auth_code"]
    if user = find_or_goto_index(User, id)

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
        set_session_user(nil)
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
                     rescue
                       nil
                     end
          confirmation = begin
                           params[:user][:password_confirmation]
                         rescue
                           nil
                         end
          if password.blank?
            @user.errors.add(:password, :validate_user_password_missing.t)
          elsif password != confirmation
            @user.errors.add(:password_confirmation,
                             :validate_user_password_no_match.t)
          elsif password.length < 5 || password.bytesize > 40
            @user.errors.add(:password, :validate_user_password_too_long.t)
          else
            User.current = @user
            set_session_user(@user)
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
        set_session_user(user)
        @user.verify
        # These are typically spammers.
        if @user.login == @user.name && @user.name.match(/^[a-z]+$/)
          subject = "Suspicious user: #{@user.login.inspect}"
          content = "Suspicious user:\n" \
                    "  login=#{@user.login.inspect}\n" \
                    "  name=#{@user.name.inspect}\n" \
                    "  email=#{@user.email.inspect}\n" \
                    "  http://mushroomobserver.org/observer/show_user?id=#{@user.id}"
          WebmasterEmail.build(@user.email, content, subject).deliver_now
        end
      end
    end
  end

  # This action is never actually used.  Its template is rendered by verify.
  def reverify # :nologin:
    fail "This action should never occur!"
  end

  # This is used by the "reverify" page to re-send the verification email.
  def send_verify # :nologin:
    if user = find_or_goto_index(User, params[:id].to_s)
      VerifyEmail.build(user).deliver_now
      flash_notice (:runtime_reverify_sent.tp + :email_spam_notice.tp)
      redirect_back_or_default(action: :welcome)
    end
  end

  # This is the welcome page for new users who just created an account.
  def welcome # :nologin:
  end

  ##############################################################################
  #
  #  :section: Login
  #
  ##############################################################################

  def login # :nologin: :prefetch:
    if request.method != "POST"
      @login = ""
      @remember = true
    else
      @login    = begin
                    params[:user][:login].to_s
                  rescue
                    ""
                  end
      @password = begin
                    params[:user][:password].to_s
                  rescue
                    ""
                  end
      @remember = begin
                    params[:user][:remember_me] == "1"
                  rescue
                    false
                  end
      user = User.authenticate(@login, @password)
      user ||= User.authenticate(@login, @password.strip)
      if !user
        flash_error :runtime_login_failed.t
      elsif !user.verified
        @unverified_user = user
        render(action: "reverify")
      else
        # logger.warn("%s, %s, %s" % [user.login, @login, @password]])
        flash_notice :runtime_login_success.t
        @user = user
        @user.last_login = now = Time.now
        @user.updated_at = now
        @user.save
        User.current = @user
        set_session_user(@user)
        if @remember
          set_autologin_cookie(@user)
        else
          clear_autologin_cookie
        end
        redirect_back_or_default(action: :welcome)
      end
    end
  end

  def email_new_password # :nologin:
    if request.method != "POST"
      @new_user = User.new
    else
      @login = params["new_user"]["login"]
      @new_user = User.where("login = ? OR name = ? OR email = ?",
                             @login, @login, @login).first
      if @new_user.nil?
        flash_error :runtime_email_new_password_failed.t(user: @login)
      else
        password = String.random(10)
        @new_user.change_password(password)
        if @new_user.save
          flash_notice (:runtime_email_new_password_success.tp +
                        :email_spam_notice.tp)
          PasswordEmail.build(@new_user, password).deliver_now
          render(action: "login")
        else
          flash_object_errors(@new_user)
        end
      end
    end
  end

  def logout_user # :nologin:
    @user = nil
    User.current = nil
    set_session_user(nil)
    clear_autologin_cookie
  end

  def show_alert # :nologin:
    if !@user
      redirect_back_or_default(action: :welcome)
    elsif !@user.alert || !@user.alert_type
      flash_warning :user_alert_missing.t
      redirect_back_or_default(action: :welcome)
    elsif request.method == "GET"
      @back = session["return-to"]
      # render alert
    elsif request.method == "POST"
      if params[:commit] == :user_alert_okay.l
        @user.alert = nil
        @user.save
      else
        @user.alert_next_showing = Time.now + 1.day
        @user.save
      end
      if !params[:back].blank?
        redirect_to(params[:back])
      else
        redirect_to("/")
      end
    end
  end

  ##############################################################################
  #
  #  :section: Preferences and Profile
  #
  ##############################################################################

  # Table for converting form value to object value
  # Used by update_prefs_from_form
  def prefs_types
    [
      [:email_comments_all, :bool],
      [:email_comments_owner, :bool],
      [:email_comments_response, :bool],
      [:email_general_commercial, :bool],
      [:email_general_feature, :bool],
      [:email_general_question, :bool],
      [:email_html, :bool],
      [:email_locations_admin, :bool],
      [:email_locations_all, :bool],
      [:email_locations_author, :bool],
      [:email_locations_editor, :bool],
      [:email_names_admin, :bool],
      [:email_names_all, :bool],
      [:email_names_author, :bool],
      [:email_names_editor, :bool],
      [:email_names_reviewer, :bool],
      [:email_observations_all, :bool],
      [:email_observations_consensus, :bool],
      [:email_observations_naming, :bool],
      [:email, :str],
      [:has_images, :content_filter],
      [:has_specimen, :content_filter],
      [:hide_authors, :enum],
      [:image_size, :enum],
      [:keep_filenames, :enum],
      [:layout_count, :int],
      [:license_id, :int],
      [:locale, :str],
      [:location_format, :enum],
      [:login, :str],
      [:theme, :str],
      [:thumbnail_maps, :bool],
      [:thumbnail_size, :enum],
      [:view_owner_id, :bool],
      [:votes_anonymous, :enum]
    ]
  end

  def prefs # :prefetch:
    @licenses = License.current_names_and_ids(@user.license)
    return unless request.method == "POST"

    update_password
    update_prefs_from_form
    update_copyright_holder if prefs_changed_successfully
  end

  def update_password
    return unless password = params["user"]["password"]
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
      when :str  then update_pref(pref, val.to_s)
      when :int  then update_pref(pref, val.to_i)
      when :bool then update_pref(pref, val == "1")
      when :enum then update_pref(pref, val ||= User.enum_default_value(pref))
      when :content_filter then update_content_filter(pref, val)
      end
    end
  end

  def update_pref(pref, val)
    @user.send("#{pref}=", val) if @user.send(pref) != val
  end

  def update_content_filter(pref, val)
    filter = eval(pref.to_s)
    val == "1" ? val = filter[:checked_val] : val = filter[:off_val]
    @user.content_filter[pref] = val
  end

  def update_copyright_holder
    return unless new_holder = @user.legal_name_change
    Image.update_copyright_holder(*new_holder, @user)
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

  def profile # :prefetch:
    @licenses = License.current_names_and_ids(@user.license)
    if request.method != "POST"
      @place_name        = @user.location ? @user.location.display_name : ""
      @copyright_holder  = @user.legal_name
      @copyright_year    = Time.now.year
      @upload_license_id = @user.license.id

    else
      for arg in [:name, :notes, :mailing_address]
        val = params[:user][arg].to_s
        @user.send("#{arg}=", val) if @user.send(arg) != val
      end

      # Make sure the given location exists before accepting it.
      @place_name = params["user"]["place_name"].to_s
      if !@place_name.blank?
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
      unless upload.blank?
        if upload.respond_to?(:original_filename)
          name = upload.original_filename.force_encoding("utf-8")
        else
          name = nil
        end
        date = Date.parse(params["date"]["copyright_year"].to_s + "0101")
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
          logger.error("Unable to upload image")
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

      legal_name_change = @user.legal_name_change
      if !@user.changed
        flash_notice(:runtime_no_changes.t)
        redirect_to(controller: "observer", action: "show_user", id: @user.id)
      elsif !@user.save
        flash_object_errors(@user)
      else
        if legal_name_change
          Image.update_copyright_holder(*legal_name_change, @user)
        end
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
    if @user && @user.image
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
  alias_method :no_comment_email,          :no_email_comments_owner
  alias_method :no_comment_response_email, :no_email_comments_response
  alias_method :no_commercial_email,       :no_email_general_commercial
  alias_method :no_consensus_change_email, :no_email_observations_consensus
  alias_method :no_feature_email,          :no_email_general_feature
  alias_method :no_name_change_email,      :no_email_names_author
  alias_method :no_name_proposal_email,    :no_email_observations_naming
  alias_method :no_question_email,         :no_email_general_question

  def no_email(type)
    if check_permission!(params[:id].to_s)
      method  = "email_#{type}="
      prefix  = "no_email_#{type}"
      success = "#{prefix}_success".to_sym
      @note   = "#{prefix}_note".to_sym
      set_val = "set_#{type}".to_sym
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

  def api_keys # :login: :norobots:
    @key = ApiKey.new
    if request.method == "POST"
      if params[:commit] == :account_api_keys_create_button.l
        create_api_key
      else
        remove_api_keys
      end
    end
  end

  def create_api_key
    @key = ApiKey.new(params[:key].permit!)
    @key.verified = Time.now
    @key.save!
    @key = ApiKey.new # blank out form for if they want to create another key
    flash_notice(:account_api_keys_create_success.t)
  rescue => e
    flash_error(:account_api_keys_create_failed.t(msg: e.to_s))
  end

  def remove_api_keys
    num_destroyed = 0
    for key in @user.api_keys
      if params["key_#{key.id}"] == "1"
        @user.api_keys.delete(key)
        num_destroyed += 1
      end
    end
    if num_destroyed > 0
      flash_notice(:account_api_keys_removed_some.t(num: num_destroyed))
    else
      flash_warning(:account_api_keys_removed_none.t)
    end
  end

  def activate_api_key # :login: :norobots:
    if key = find_or_goto_index(ApiKey, params[:id].to_s)
      if check_permission!(key)
        key.verify!
        flash_notice(:account_api_keys_activated.t(notes: key.notes))
      end
      redirect_to(action: :api_keys)
    end
  rescue => e
    flash_error(e.to_s)
  end

  def edit_api_key # :login: :norobots:
    if @key = find_or_goto_index(ApiKey, params[:id].to_s)
      if check_permission!(@key)
        if request.method == "POST"
          if params[:commit] == :UPDATE.l
            @key.update!(params[:key].permit!)
            flash_notice(:account_api_keys_updated.t)
          end
          redirect_to(action: :api_keys)
        end
      else
        redirect_to(action: :api_keys)
      end
    end
  rescue => e
    flash_error(e.to_s)
  end

  ##############################################################################
  #
  #  :section: Admin utilities
  #
  ##############################################################################

  def turn_admin_on # :root:
    session[:admin] = true if @user && @user.admin && !is_in_admin_mode?
    redirect_back_or_default(controller: :observer, action: :index)
  end

  def turn_admin_off # :root:
    session[:admin] = nil
    redirect_back_or_default(controller: :observer, action: :index)
  end

  def add_user_to_group # :root:
    redirect = true
    if is_in_admin_mode?
      if request.method == "POST"
        user_name  = params["user_name"].to_s
        group_name = params["group_name"].to_s
        user       = User.find_by_login(user_name)
        group      = UserGroup.find_by_name(group_name)
        flash_error :add_user_to_group_no_user.t(user: user_name)    unless user
        flash_error :add_user_to_group_no_group.t(group: group_name) unless group
        if user && group
          if user.user_groups.member?(group)
            flash_warning :add_user_to_group_already. \
              t(user: user_name, group: group_name)
          else
            user.user_groups << group
            flash_notice :add_user_to_group_success. \
              t(user: user_name, group: group_name)
          end
        end
      else
        redirect = false
      end
    else
      flash_error :permission_denied.t
    end
    if redirect
      redirect_back_or_default(controller: "observer", action: "index")
    end
  end

  def create_alert # :root:
    redirect = true
    id = params[:id].to_s
    if @user2 = find_or_goto_index(User, id)
      if is_in_admin_mode?
        if request.method == "GET"
          # render form
          redirect = false
        elsif request.method == "POST"
          if params[:commit] == :user_alert_save.l
            @user2.alert_type  = params[:user2][:alert_type]
            @user2.alert_notes = params[:user2][:alert_notes]
            if params[:user2][:alert_type].blank?
              flash_error :user_alert_missing_type.t
              @user2.errors.add(:alert_type)
              redirect = false
            else
              @user2.alert_created_at   = now = Time.now
              @user2.alert_next_showing = now
              @user2.alert_user_id      = @user.id
              @user2.save
              flash_notice :user_alert_saved.t(user: @user2.login)
            end
          else
            @user2.alert = nil
            @user2.save
            flash_notice :user_alert_deleted.t(user: @user2.login)
          end
        end
      end
      redirect_to(controller: :observer, action: :show_user, id: id) if redirect
    end
  end

  # This is messy, but the new User#erase_user method makes a pretty good
  # stab at the problem.
  def destroy_user # :root:
    if is_in_admin_mode?
      id = params["id"]
      unless id.blank?
        user = User.safe_find(id)
        User.erase_user(id) if user
      end
    end
    redirect_back_or_default("/")
  end

  ##############################################################################
  #
  #  :section: Testing
  #
  ##############################################################################

  # This is used to test the autologin feature.
  def test_autologin
  end

  # This is used to test the flash error mechanism in the unit tests.
  def test_flash # :nologin:
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
      render(text: "", layout: true)
    end
  end

  ################################################################################
end
