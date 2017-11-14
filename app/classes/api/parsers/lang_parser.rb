class API
  module Parsers
    # Parse API locales
    class LangParser < EnumParser
      def initialize(api, key, args)
        args[:default] ||= Language.official.locale
        args[:limit]   ||= Language.all.map(&:locale)
        super
      end

      def parse(str)
        super(Language.lang_from_locale(str))
      end
    end
  end
end
