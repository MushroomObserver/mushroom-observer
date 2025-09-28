# frozen_string_literal: true

#  ==== User authentication
#  autologin::              (filter: determine which user is logged in)
#  login_for_ajax::         (filter: minimal version of autologin for ajax)
#  permission?::            Make sure current User is the right one.
#  permission!::            Same, but flashes "denied" message, too.
#  reviewer?::              Is the current User a reviewer?
#  in_admin_mode?::         Is the current User in admin mode?
#  autologin_cookie_set::   (set autologin cookie)
#  clear_autologin_cookie:: (clear autologin cookie)
#  session_user_set::       (store user in session -- id only)
#  session_user::           (retrieve user from session)
#
module ApplicationController::Authentication
  def self.included(base)
    base.helper_method(:permission?, :reviewer?, :in_admin_mode?)
  end

  ##############################################################################
  #
  #  :section: User authentication
  #
  ##############################################################################

  # Filter that should run before everything else.  Establishes whether a User
  # is logged in or not.
  #
  # Stores the currently logged-in User in the "globals" <tt>@user</tt> and
  # <tt>User.current</tt>, as well as the session.  (The first is visible to
  # all controller instances and views; the second is visible to the entire
  # website application.)
  #
  # It first checks if the User is already logged in, i.e. is stored in the
  # session.  If not, it checks for an autologin cookie on the User's browser,
  # and logs them in automatically if so.
  #
  # In both cases, it makes sure the User actually exists and is verified.  If
  # not, the "user" is immediately logged out and the autologin cookie is
  # destroyed.
  #
  def autologin
    # render(plain: "Sorry, we've taken MO down to test something urgent."\
    #               "We'll be back in a few minutes. -Jason", layout: false)
    # return false

    # if browser.bot?
    #   render(status: 503, text: "robots are temporarily blocked from MO",
    #          layout: false)
    #   return false
    # end

    try_user_autologin(session_user)
    make_logged_in_user_available_to_everyone
    track_last_time_user_made_a_request
    block_suspended_users
    clear_admin_mode_for_nonadmins
  end

  private ##########

  def clear_user_globals
    @user = nil
    User.current = nil
  end

  # Save a lookup of the mrtg stats "user".
  MRTG_USER_ID = 164_054
  private_constant(:MRTG_USER_ID)

  def try_user_autologin(user_from_session)
    if Rails.env.production? && request.remote_ip == "127.0.0.1"
      # Request from the server itself, MRTG needs to log in to test page loads.
      login_valid_user(User.find(MRTG_USER_ID))
    elsif user_verified_and_allowed?(user_from_session)
      # User was already logged in.
      @user = user_from_session
    elsif user_verified_and_allowed?(user = validate_user_in_autologin_cookie)
      # User had "remember me" cookie set.
      login_valid_user(user)
    else
      delete_invalid_cookies
    end
  end

  def user_verified_and_allowed?(user)
    user&.verified && !user.blocked?
  end

  def validate_user_in_autologin_cookie
    return unless (cookie = cookies["mo_user"]) &&
                  (split = cookie.split) &&
                  (user = User.where(id: split[0]).first) &&
                  (split[1] == user.auth_code)

    user
  end

  def login_valid_user(user)
    @user = session_user_set(user)
    @user.last_login = Time.current
    @user.save

    # Reset cookie to push expiry forward.  This way it will continue to
    # remember the user until they are inactive for over a month.  (Else
    # they'd have to login every month, no matter how often they login.)
    autologin_cookie_set(user)
  end

  def delete_invalid_cookies
    clear_autologin_cookie
    session_user_set(nil)
  end

  def make_logged_in_user_available_to_everyone
    User.current = @user
    logger.warn("user=#{@user ? @user.id : "0"} " \
                "robot=#{browser.bot? ? "Y" : "N"} " \
                "ip=#{request.remote_ip}")
  end

  # Track when user last requested a page, but update at most once an hour.
  def track_last_time_user_made_a_request
    last_activity = @user&.last_activity&.to_fs("%Y%m%d%H")
    now = Time.current.to_fs("%Y%m%d%H")
    return if !@user || last_activity && last_activity >= now

    @user.last_activity = Time.current
    @user.save
  end

  def block_suspended_users
    return true unless @user&.blocked # Tell Rails to continue processing.

    render(plain: "Your account has been deleted.", layout: false)
    false # Tell Rails to stop processing.
  end

  def clear_admin_mode_for_nonadmins
    session[:admin] = false if session[:admin] && !@user&.admin
  end

  public ##########

  # ----------------------------
  #  "Public" methods.
  # ----------------------------

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  (*NOTE*: this is available to views.)
  def permission?(obj)
    in_admin_mode? || correct_user_for_object?(obj)
  end

  def correct_user_for_object?(obj)
    owned_by_user?(obj) || editable_by_user?(obj) || obj_is_user?(obj)
  end

  def owned_by_user?(obj)
    obj.respond_to?(:user_id) && @user&.id == obj.user_id
  end

  # Always send a @user to the model instance method `can_edit?`
  # so it doesn't have to call User.current.
  def editable_by_user?(obj)
    obj.try(:can_edit?, @user)
  end

  def obj_is_user?(obj)
    (obj.is_a?(String) || obj.is_a?(Integer)) && obj.to_i == @user.id
  end

  private :correct_user_for_object?, :owned_by_user?, :editable_by_user?,
          :obj_is_user?

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  Flashes a "denied" error message if false.
  #
  #   def destroy_thing
  #     @thing = Thing.find(params[:id].to_s)
  #     if permission!(@thing)
  #       @thing.destroy
  #       flash_notice "Success!"
  #     end
  #     redirect_to(:action => :show_thing)
  #   end
  #
  def permission!(obj, error_message: :permission_denied.l)
    flash_error(error_message) unless (permission = permission?(obj))
    permission
  end

  def can_delete?(obj)
    permission!(obj, error_message: :runtime_no_destroy.l(type: obj.type_tag))
  end

  def can_edit?(obj)
    permission!(obj, error_message: :runtime_no_update.l(type: obj.type_tag))
  end

  # Make sure user is logged in and has posted something -- i.e., not a spammer.
  def require_successful_user
    return true if @user&.successful_contributor?

    flash_warning(:unsuccessful_contributor_warning.t)
    redirect_back_or_default("/")
    false
  end

  # Is the current User a reviewer?  Returns true or false.  (*NOTE*: this is
  # available to views.)
  def reviewer?
    result = false
    result = @user.in_group?("reviewers") if @user
    result
  end
  # helper_method :reviewer?

  # Is the current User in admin mode?  Returns true or false.  (*NOTE*: this
  # is available to views.)
  def in_admin_mode?
    session[:admin]
  end
  # helper_method :in_admin_mode?

  # ----------------------------
  #  "Private" methods.
  # ----------------------------

  # Create/update the auto-login cookie.
  def autologin_cookie_set(user)
    cookies["mo_user"] = {
      value: "#{user.id} #{user.auth_code}",
      expires: 1.month.from_now,
      same_site: :lax
    }
  end

  # Destroy the auto-login cookie.
  def clear_autologin_cookie
    cookies.delete("mo_user")
  end

  # Store User in session (id only).
  def session_user_set(user)
    session[:user_id] = user&.id
    user
  end

  # Retrieve the User from session.  Returns freshly loaded User object or nil.
  # (Does not check verified status or anything.)
  def session_user
    User.safe_find(session[:user_id])
  end
end
