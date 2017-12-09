class API
  module Parsers
    # Parse locales for API.
    class LangParser < EnumParser
      def initialize(api, key, args)
        args[:default] ||= Language.official.locale_region
        args[:limit]   ||= Language.all.map(&:locale_region)
        super
      end

      def parse(str)
        val = exact_match(str)
        return val if val
        val = first_part_match(str)
        return val if val
        raise BadLimitedParameterValue.new(str, limit)
      end

      def exact_match(str)
        Language.all.each do |lang|
          return lang.locale_region if str.casecmp(lang.locale_region).zero?
        end
        nil
      end

      def first_part_match(str)
        str = str.split("-").first || return
        Language.all.each do |lang|
          return lang.locale_region if str.casecmp(lang.locale).zero?
        end
        nil
      end
    end
  end
end
