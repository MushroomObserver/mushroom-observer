# frozen_string_literal: true

class API2
  module Parsers
    # Base class for API2 object parsers.
    class ObjectBase < Base
      def parse(str)
        raise(BadParameterValue.new(str, model.type_tag)) if str.blank?

        obj = find_object(str)
        raise(ObjectNotFoundByString.new(str, model)) unless obj

        check_permissions!(obj)
        value_based_on_as_argument(args[:as], str, obj)
      end

      def find_object(str)
        try_finding_by_id(str) || try_finding_by_string(str)
      end

      def try_finding_by_id(str)
        return nil unless /^\d+$/.match?(str)

        obj = model.safe_find(str.to_i)
        return obj if obj

        raise(ObjectNotFoundById.new(str, model))
      end

      def try_finding_by_string(str)
        raise(BadParameterValue.new(str, key))
      end

      def check_permissions!(obj)
        check_if_owner!(obj)        if args[:must_be_owner]
        check_view_permission!(obj) if args[:must_have_view_permission]
        check_edit_permission!(obj) if args[:must_have_edit_permission]
      end

      def check_if_owner!(obj)
        return if obj.user == api.user

        raise(MustBeOwner.new(obj))
      end

      def check_view_permission!(obj)
        return if obj.can_view?(api.user)

        raise(MustHaveViewPermission.new(obj))
      end

      def check_edit_permission!(obj)
        return if obj.can_edit?(api.user)

        raise(MustHaveEditPermission.new(obj))
      end

      # ------------------------------------------------------------------------

      private

      def value_based_on_as_argument(arg, str, obj)
        case arg
        when :verbatim
          str
        when :id
          obj.id
        else
          obj
        end
      end
    end
  end
end
