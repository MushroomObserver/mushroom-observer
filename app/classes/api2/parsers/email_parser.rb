# frozen_string_literal: true

class API2
  module Parsers
    # Parse email addresses for API.
    class EmailParser < StringParser
      # See RFC 5322. This is overpermissive, as email addresses are not
      # allowed to start or end with a dot.  It is also not permissive enough,
      # since the standard also allows much more lenient strings if double-
      # quoted, but that gets really confusing with backslashes, etc. Lastly,
      # this is too permissive with respect to the domain part for a few
      # unimportant reasons.  Whatever.  Close enough!
      EMAIL = /^[\w.!#$%&'*+\/=?^_‘{|}~-]+@[\w\-]+(\.[\w\-]+)+$/.freeze

      def parse(str)
        val = super || return
        return val if EMAIL.match?(val)

        raise(BadParameterValue.new(val, :email))
      end
    end
  end
end
