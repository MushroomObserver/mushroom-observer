class API
  module Parsers
    # Parse names for API.
    class NameParser < ObjectBase
      def model
        Name
      end

      def find_object(str)
        val = try_finding_by_id(str) ||
              try_finding_by_string(str)
        val = correct_spelling(val) if args[:correct_spelling]
        val
      end

      def try_finding_by_string(str)
        matches = Name.where("search_name = ? OR text_name = ?", str, str)
        if matches.empty?
          raise NameDoesntParse.new(str) unless Name.parse_name(str)

          raise ObjectNotFoundByString.new(str, Name)
        end
        return str if args[:as] == :verbatim

        matches = restrict_to_exact_matches_if_possible(matches, str)
        matches = restrict_to_approved_names_if_possible(matches)
        raise AmbiguousName.new(str, matches) if matches.length > 1

        matches.first
      end

      def restrict_to_exact_matches_if_possible(matches, str)
        exact_matches = matches.select { |n| n.search_name == str }
        exact_matches.any? ? exact_matches : matches
      end

      def restrict_to_approved_names_if_possible(matches)
        approved = matches.reject(&:deprecated)
        approved.any? ? approved : matches
      end

      def correct_spelling(val)
        val.correct_spelling || val
      end
    end
  end
end
