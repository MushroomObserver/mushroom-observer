class API
  module Parsers
    # Parse API names
    class NameParser < ObjectBase
      def model
        Name
      end

      def parse(str)
        raise BadParameterValue.new(str, model.type_tag) if str.blank?
        val = try_finding_by_id(str) ||
              try_finding_by_string(str)
        val = correct_spelling(val) if args[:correct_spelling]
        check_view_permission!(val) if args[:must_have_view_permission]
        check_edit_permission!(val) if args[:must_have_edit_permission]
        val
      end

      def try_finding_by_string(str)
        val = Name.where("deprecated IS FALSE
                         AND (text_name=? OR search_name=?)", str, str)
        val = Name.where("text_name=? OR search_name=?", str, str) if val.empty?
        if val.empty?
          raise NameDoesntParse.new(str) unless Name.parse_name(str)
          raise ObjectNotFoundByString.new(str, Name)
        end
        raise AmbiguousName.new(str, val) if val.length > 1
        val.first
      end

      def correct_spelling(val)
        val.correct_spelling || val
      end
    end
  end
end
