# frozen_string_literal: true

class API2
  module Parsers
    # Parse users for API.
    class UserParser < ObjectBase
      def model
        User
      end

      def try_finding_by_string(str)
        User.where("login = ? OR name = ? OR email = ?", str, str, str).first
      end
    end
  end
end
