# frozen_string_literal: true

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
