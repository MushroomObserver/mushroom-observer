# frozen_string_literal: true

class API
  module Parsers
    # Parse users for API.
    class UserParser < ObjectBase
      def model
        User
      end

      def try_finding_by_string(str)
        User.where("login = ? OR name = ?", str, str).first
      end
    end
  end
end
