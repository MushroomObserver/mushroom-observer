# frozen_string_literal: true

class API2
  module Parsers
    # Parse enumerated lists for API.
    class EnumParser < Base
      attr_accessor :limit

      # Always has to have limit argument: the set of allowed values.
      def initialize(*args)
        super
        self.limit = self.args[:limit]
        raise("missing limit!") unless limit
      end

      def parse(str)
        limit.each do |val|
          return val if str.casecmp(val.to_s).zero?
        end
        raise(BadLimitedParameterValue.new(str, limit))
      end

      # Make sure range is in correct order, and reduce trivial ranges to
      # just a single value.
      def parse_range
        val = super || return
        return val.begin if val.begin == val.end

        val.reverse! if limit.index(val.begin) > limit.index(val.end)
        val
      end
    end
  end
end
