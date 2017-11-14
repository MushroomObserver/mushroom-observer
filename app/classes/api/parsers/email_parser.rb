class API
  module Parsers
    # Parse API email addresses
    class EmailParser < StringParser
      EMAIL = /^[\w\-]+@[\w\-]+(\.[\w\-]+)+$/

      def parse(str)
        val = super || return
        return val if val.match(EMAIL)
        raise BadParameterValue.new(val, :email)
      end
    end
  end
end
