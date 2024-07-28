# frozen_string_literal: true

# This is the connection class for the ActionCable websocket connection,
# responsible for setting the current_user for the connection. Any live updates
# over websockets need to be authenticated like regular requests, but they don't
# hit the regular controller actions, so we need to authenticate them
# separately. The current_user is set by checking the autologin cookie.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if (verified_user = validate_user_in_autologin_cookie)
        verified_user
      else
        reject_unauthorized_connection
      end
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
