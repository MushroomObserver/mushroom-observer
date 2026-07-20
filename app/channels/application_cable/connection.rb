# frozen_string_literal: true

# This is the connection class for the ActionCable websocket connection,
# responsible for setting the current_user for the connection. Any live updates
# over websockets need to be authenticated like regular requests, but they don't
# hit the regular controller actions, so we need to authenticate them
# separately. The current_user is identified from the Rails session first
# (works regardless of how the user logged in), falling back to the
# autologin cookie (covers a session-less reconnect while "remember me"
# is still valid).
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      validate_user_in_session || validate_user_in_autologin_cookie ||
        reject_unauthorized_connection
    end

    # Mirrors ApplicationController::Authentication#session_user +
    # #user_verified_and_allowed?.
    def validate_user_in_session
      user = User.safe_find(request.session[:user_id])
      user if user&.verified && !user.blocked?
    end

    def validate_user_in_autologin_cookie
      return unless (cookie = cookies["mo_user"]) &&
                    (split = cookie.split) &&
                    (user = User.where(id: split[0]).first) &&
                    (split[1] == user.auth_code)

      user
    end
  end
end
