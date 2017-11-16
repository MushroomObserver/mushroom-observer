class API
  module Parsers
    # Base class for API object parsers.
    class ObjectBase < Base
      def parse(str)
        raise BadParameterValue.new(str, model.type_tag) if str.blank?
        val = find_object(str)
        raise ObjectNotFoundByString.new(str, model) unless val
        check_view_permission!(val) if args[:must_have_view_permission]
        check_edit_permission!(val) if args[:must_have_edit_permission]
        args[:as] == :id ? val.id : val
      end

      def find_object(str)
        try_finding_by_id(str) || try_finding_by_string(str)
      end

      def try_finding_by_id(str)
        return nil unless str =~ /^\d+$/
        obj = model.safe_find(str.to_i)
        return obj if obj
        raise ObjectNotFoundById.new(str, model)
      end

      def try_finding_by_string(str)
        raise BadParameterValue.new(str, key)
      end

      def check_view_permission!(obj)
        return if obj.has_view_permission?(api.user)
        raise MustHaveViewPermission.new(obj)
      end

      def check_edit_permission!(obj)
        return if obj.has_edit_permission?(api.user)
        raise MustHaveEditPermission.new(obj)
      end
    end
  end
end
