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
    base.helper_method(:permission?, :reviewer?, :in_admin_mode?,
                       :current_user)
  end

  # Request-scoped accessor for the logged-in User. Lives on the
  # controller so the request/session boundary is the only thing
  # that can answer "who's looking at this page" - no model-level
  # ambient global anywhere. `helper_method` exposes it to the view
  # context; `Components::Base` registers it as a value helper for
  # Phlex views.
  def current_user
    @user
  end

  ##############################################################################
  #
  #  :section: User authentication
  #
  ##############################################################################

  # rubocop:disable MO/NoLongCommentBlock
  # Filter that should run before everything else.  Establishes whether a User
  # is logged in or not.
  #
  # Stores the currently logged-in User in the "global" <tt>@user</tt> and
  # in the session.
  #
  # It first checks if the User is already logged in, i.e. is stored in the
  # session.  If not, it checks for an autologin cookie on the User's browser,
  # and logs them in automatically if so.
  #
  # In both cases, it makes sure the User actually exists and is verified.  If
  # not, the "user" is immediately logged out and the autologin cookie is
  # destroyed.
  #
  # rubocop:enable MO/NoLongCommentBlock
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
    log_login_activity
    track_last_time_user_made_a_request
    block_suspended_users
    clear_admin_mode_for_nonadmins
  end

  private ##########

  def clear_user_globals
    @user = nil
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

  # A blank stored `auth_code` must match nothing: a cookie carrying
  # only an id splits to a nil secret, which would otherwise compare
  # equal to a null code and authenticate without one.
  def validate_user_in_autologin_cookie
    return unless (cookie = cookies["mo_user"]) &&
                  (split = cookie.split) &&
                  (user = User.where(id: split[0]).first) &&
                  user.auth_code.present? &&
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

  def log_login_activity
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

  # Always send a @user to the model instance method `can_edit?` -
  # models never read an ambient global for this.
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
    session[:admin] == true
  end
  # helper_method :in_admin_mode?

  # ----------------------------
  #  "Private" methods.
  # ----------------------------

  private

  # Switch the apparent logged-in user in the session. Used by both
  # LogoutController (to restore an admin's real account after sudo) and
  # Admin::SessionController (to switch into another user).
  def switch_to_user(new_user)
    update_sudo_session(new_user)
    @user = new_user
    session_user_set(new_user)
  end

  # `real_auth` binds the stored admin id to that admin's credential,
  # the way `session[:auth]` binds `user_id`. An id by itself restores
  # the admin to whoever holds the session, so a copy of a switched
  # session would outlive a rotation of that admin's code.
  def update_sudo_session(new_user)
    if session[:real_user_id].blank?
      enter_sudo_session
    elsif session[:real_user_id] == new_user.id
      leave_sudo_session
    end
  end

  def enter_sudo_session
    session[:real_user_id] = @user&.id
    session[:real_auth] = @user&.auth_code
    session[:admin] = nil
  end

  def leave_sudo_session
    session[:real_user_id] = nil
    session[:real_auth] = nil
    session[:admin] = true
  end

  # The admin behind a switch-user session, for the two actions that
  # act on `session[:real_user_id]`. Nil unless the session can produce
  # the credential stored at switch time.
  def sudo_real_user
    return if session[:real_user_id].blank?

    user = User.safe_find(session[:real_user_id])
    user if user && sudo_auth_valid?(user)
  end

  def sudo_auth_valid?(user)
    session[:real_auth].present? && session[:real_auth] == user.auth_code
  end

  def clear_sudo_session
    session[:real_user_id] = nil
    session[:real_auth] = nil
    session[:admin] = false
  end

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

  # A logged-in user whose auth_code has just changed still holds the
  # previous one in their session and autologin cookie. Re-issue both,
  # so changing a password keeps them logged in to the browser they
  # changed it in while logging out every other one.
  def refresh_login_credentials(user)
    session_user_set(user)
    autologin_cookie_set(user) if autologin_cookie_belongs_to?(user)
  end

  # In switch-user mode the cookie is the admin's while `user` is the
  # account being edited, so re-issuing it would hand the admin's
  # browser someone else's credentials.
  def autologin_cookie_belongs_to?(user)
    (cookie = cookies["mo_user"]).present? && cookie.split[0] == user.id.to_s
  end

  # Store User in session (id, plus the credential binding the session
  # to them).
  def session_user_set(user)
    session[:user_id] = user&.id
    session[:auth] = user&.auth_code
    clear_sudo_session if user.nil?
    user
  end

  # Retrieve the User from session.  Returns freshly loaded User object or nil.
  # (Does not check verified status or anything.)
  def session_user
    user = User.safe_find(session[:user_id])
    return unless user && session_auth_valid?(user)

    user
  end

  # The session carries the user's `auth_code`, so rotating that code
  # invalidates every open session for them, not just the autologin
  # cookie. A session holding no code predates this binding and is
  # treated as invalid.
  def session_auth_valid?(user)
    session[:auth].present? && session[:auth] == user.auth_code
  end

  # For actions that skip the standard `autologin` filter (via
  # `disable_filters`, to avoid its autologin-cookie-fallback overhead
  # on lightweight AJAX endpoints) but still need to know who's logged
  # in. `session[:user_id]` isn't touched by skipping `autologin` -
  # only the extra steps are skipped - so `session_user` is always
  # available here. Applies the same `user_verified_and_allowed?`
  # check `autologin` does, so a blocked/unverified user's session
  # resolves to nil here too, same as everywhere else on the site.
  #
  # Only sets `@user` - there's no ambient global to also set anymore.
  def set_user_from_session
    user = session_user
    @user = user if user_verified_and_allowed?(user)
  end
end
