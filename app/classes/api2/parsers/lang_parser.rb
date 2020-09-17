# frozen_string_literal: true

class API2
  module Parsers
    # Parse locales for API.
    class LangParser < EnumParser
      def initialize(api, key, args)
        args[:default] ||= Language.official.locale
        args[:limit]   ||= Language.all.map(&:locale)
        super
      end

      def parse(str)
        lang = Language.find_by_locale(str)
        return lang.locale if lang

        raise(BadLimitedParameterValue.new(str, limit))
      end
    end
  end
end
