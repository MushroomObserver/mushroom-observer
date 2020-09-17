# frozen_string_literal: true

class API2
  module Parsers
    # Parse objects for API2.
    class ObjectParser < ObjectBase
      attr_accessor :limit

      # Always has to have limit argument: the set of allowed object types.
      def initialize(*args)
        super
        self.limit = self.args[:limit]
        raise("missing limit!") unless limit
      end

      def parse(str)
        type, id = parse_object_type(str)
        val = find_object(type, id, str)
        check_view_permission!(val) if args[:must_have_view_permission]
        check_edit_permission!(val) if args[:must_have_edit_permission]
        val
      end

      def parse_object_type(str)
        match = str.match(/^([a-z][ _a-z]*[a-z]) #?(\d+)$/i)
        raise(BadParameterValue.new(str, :object)) unless match

        [match[1].tr(" ", "_").downcase, match[2]]
      end

      def find_object(type, id, str)
        val = nil
        limit.each do |model|
          next unless model.type_tag.to_s.casecmp(type).zero?

          val = model.safe_find(id)
          return val if val

          raise ObjectNotFoundById.new(str, model)
        end
        raise(BadLimitedParameterValue.new(str, limit.map(&:type_tag)))
      end
    end
  end
end
